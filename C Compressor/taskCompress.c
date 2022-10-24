/*
 * taskCompress.c
 *
 *  Created on: 8 Aug 2022
 *      Author: wonde
 */
#include "../../components/taskCompress/taskCompress.h"

static size_t ramBufLen = 16384/4; //we count in uint32_t, not bytes.
static size_t ramBufSize = 16384;
static uint32_t* ramBuf = NULL;


void taskCompress( void * pvParameters ) {

	//State variables
	SYSTEM_STATES_t uState = STANDBY;
	BaseType_t queueErr;

	//Data variables
	RadarFramePacket_t *pRadarData = NULL;
	RadarFramePacket_t *pCompressedData = NULL;
	void *rawBuffer = NULL;
	void *compBuffer = NULL;
	ramBuf = heap_caps_malloc(ramBufSize, (MALLOC_CAP_INTERNAL | MALLOC_CAP_DMA));
	size_t bytesWritten = 0;
	size_t bytesRead = 0;
	size_t rawBufferLen = RADAR_RAWBUFFER_LEN*(sizeof(RadarFramePacket_t)+RADAR_DATA_MAX_BINS*(sizeof(RADAR_DATA_TYPE)*1+sizeof(RADAR_DFRAME_DATA_TYPE)*(RADAR_DATA_FPP-1)))/2;
	size_t compBufferLen = RADAR_CMPBUFFER_LEN*(sizeof(RadarFramePacket_t)+RADAR_DATA_MAX_BINS*(sizeof(RADAR_DATA_TYPE)*1+sizeof(RADAR_DFRAME_DATA_TYPE)*(RADAR_DATA_FPP-1)))/2;
	size_t framePacketSize;
	size_t framePacketHeaderSize = sizeof(RadarFramePacket_t);
	int status;
	int packetCount = 0;


	//Timing variables
	int64_t timePrev;
	uint32_t timeMeasure;

	//Task communication variables
	taskParameters_t *ptaskParameter = (taskParameters_t*)pvParameters;
	xQueueHandle sdQueueHandle = ptaskParameter->sdQueueHandle;
	xQueueHandle sdFreeQueueHandle = ptaskParameter->sdFreeQueueHandle;
	xQueueHandle dataQueueHandle = ptaskParameter->dataQueueHandle;
	xQueueHandle radarFreeQueueHandle = ptaskParameter->radarFreeQueueHandle;
	EventBits_t uStateBits;
	EventGroupHandle_t xSystemStateEventGroup = ptaskParameter->xSystemStateEventGroup;




	for (;;) {

		if (uState == STANDBY) {
			xEventGroupWaitBits(xSystemStateEventGroup, (RADAR_ACTIVE_BIT | DRIVER_READY_BIT | SD_MOUNT_BIT | SDSERVICE_READY_BIT), pdFALSE, pdTRUE, portMAX_DELAY); //note this means we'll hang if we have no SD card
			//Initialize memory pointers
			queueErr = xQueueReceive(sdFreeQueueHandle, &compBuffer, portMAX_DELAY); //this will return when taskSDService has finished initialization (whether or not there is SD card present)
			queueErr = xQueueReceive(dataQueueHandle, &rawBuffer, portMAX_DELAY); //Note this will only return when we start getting raw data from radar
			compBuffer = memset(compBuffer,1,compBufferLen); //Set the first half-buffer to 1 all bytes (debugging)
			pRadarData = rawBuffer;
			pCompressedData = compBuffer;
			bytesWritten = 0;
			bytesRead = 0;
			packetCount = 0;
			framePacketSize = (sizeof(RadarFramePacket_t)+pRadarData->bytes);
			uState = RECORD;
		}
		else {
			if (((rawBufferLen-bytesRead)>=framePacketSize) && (rawBuffer != NULL)) {
						//update radarPacket pointer to the new location in the existing buffer if there is enough space left
				pRadarData = rawBuffer + bytesRead;
			}
			else {
				//Otherwise switch the ping pong buffer by sending the previously read data in radarFreeQueue and pulling new data from dataQueue
				if (rawBuffer != NULL) queueErr = xQueueSendToBack(radarFreeQueueHandle, &rawBuffer, 0);
				//bytesRead = 0;
				if (xQueueReceive(dataQueueHandle, &rawBuffer, TASK_COMPRESS_QUEUETIMEOUT)) bytesRead = 0;
				else {
					uStateBits = xEventGroupGetBits(xSystemStateEventGroup);
					if (((uStateBits & (RADAR_ACTIVE_BIT|DRIVER_READY_BIT)) == 0) && ((uStateBits & (SD_MOUNT_BIT|SDSERVICE_READY_BIT)) == (SD_MOUNT_BIT|SDSERVICE_READY_BIT))) {
						printf("COMPRESS: DEBUG: Received RECORD END\n");
						//if (uxQueueMessagesWaiting(radarFreeQueueHandle) < 2) queueErr = xQueueSendToBack(radarFreeQueueHandle, &rawBuffer, 0);
						memset((void*)pCompressedData,0,compBufferLen-bytesWritten);
						//queueErr = xQueueSendToBack(sdQueueHandle, &compBuffer, 0);
						queueErr = xQueueSendToBack(sdFreeQueueHandle, &compBuffer, 0);
						uState = STANDBY;
					}
					rawBuffer = NULL;
					continue;
				}

				//Update radarPacket pointer to the start of the new buffer
				pRadarData = rawBuffer;

				//Update framePacketSize
				if (pRadarData != NULL) framePacketSize = (sizeof(RadarFramePacket_t)+pRadarData->bytes);
				//if ((uStateBits & (RADAR_ACTIVE_BIT|DRIVER_READY_BIT)) == (RADAR_ACTIVE_BIT|DRIVER_READY_BIT)) framePacketSize = (sizeof(RadarFramePacket_t)+pRadarData->bytes);
			}

			//Process any changes to the writing buffer

			//First we check whether we have at least one uncompressed framePacket's
			//worth of space left to write, header included (worst case scenario) and if not we zero
			//the rest of the data and push to sdQueue
			if ((compBufferLen-bytesWritten)<framePacketSize) {

				//set the rest of the buffer to 0
				pCompressedData = memset((void*)pCompressedData,0,compBufferLen-bytesWritten);
				//printf("COMPRESS: DEBUG: Wrote %d bytes (%d frame packets) and terminated with %d bytes as zeroes, sending half-buffer to sd card queue...\n", bytesWritten, packetCount, compBufferLen-bytesWritten);

				//debug framePacket counter in the buffer
				packetCount = 0;

				//push the buffer and request a new one
				queueErr = xQueueSendToBack(sdQueueHandle, &compBuffer, 0);

				queueErr = xQueueReceive(sdFreeQueueHandle, &compBuffer, portMAX_DELAY);
				//printf("COMPRESS: DEBUG: Received new buffer for compressed data at address %p...\n", compBuffer);

				//DEBUG: we clear the previous buffer (we shouldn't have to do this, remove for production)
				compBuffer = memset(compBuffer,1,compBufferLen);


				//Reset bytesWritten counter
				bytesWritten = 0;
				//Reset pointer to pCompressedData
				pCompressedData = compBuffer;
			}

			if ((pCompressedData != NULL) && (pRadarData != NULL)) //We have valid data to work with
			{

				timePrev = esp_timer_get_time();

				//printf("COMPRESSOR: bytes written is now: %d and pCompressedData is now %p\n", bytesWritten, pCompressedData);

				//Copy the framePacket header
				memcpy(pCompressedData,pRadarData,sizeof(RadarFramePacket_t));

				//printf("COMPRESSOR: we copy the frame packet header of size %d to the compressed data buffer\n", sizeof(RadarFramePacket_t));

				//update bytesWritten
				bytesWritten += sizeof(RadarFramePacket_t);

				//printf("COMPRESSOR: bytes written is now: %d and pCompressedData is now %p\n", bytesWritten, pCompressedData);

				//update bytesRead
				bytesRead += sizeof(RadarFramePacket_t) + pRadarData->bytes;

				//Compress the data portion of the framePacket
				//status = compressor(pRadarData->keyFrameData, pRadarData->bytes, (uint32_t*)pCompressedData->keyFrameData, pRadarData->datalen*RADAR_DATA_FPP);
				//printf("COMPRESSOR: We compress data starting to write at %p\n", (uint32_t*)((void*)pCompressedData+sizeof(RadarFramePacket_t)));
				status = compressor(pRadarData->keyFrameData, pRadarData->bytes, (uint32_t*)((void*)pCompressedData+sizeof(RadarFramePacket_t)), pRadarData->datalen*RADAR_DATA_FPP);

				//Check pCompressedData->bytes value to determine if compression was
				//successful in reducing the size of the data compared to uncompressed
				//if not, memcpy
				if (status < 0) {
					printf("COMPRESS: WARNING: Did not manage to compress below uncompressed data size for framePacket number %d\n", pRadarData->frameNumber);
					memcpy(pCompressedData, pRadarData, framePacketSize-framePacketHeaderSize);
					pCompressedData->bytes = pRadarData->datalen*(sizeof(RADAR_DATA_TYPE)*1+sizeof(RADAR_DFRAME_DATA_TYPE)*(RADAR_DATA_FPP-1));
				}
				else {
					pCompressedData->bytes = (size_t)status;
					if (pCompressedData->format == DOWNCONVERT) pCompressedData->format = HUFFMAN_DOWNCONVERT;
					else pCompressedData->format = HUFFMAN_RAW;
				}

				//printf("COMPRESSOR: The compression function returns %d bytes written\n", status);

				//Update bytesWritten, pointers and diagnostic variables
				bytesWritten += pCompressedData->bytes;
				pCompressedData = compBuffer + bytesWritten;
				packetCount++;

				//printf("COMPRESSOR: bytes written is now: %d and pCompressedData is now %p\n", bytesWritten, pCompressedData);

				timeMeasure = (uint32_t)((esp_timer_get_time()-timePrev));
				if (ptaskParameter->packetCompressTime<timeMeasure) ptaskParameter->packetCompressTime = timeMeasure;

			}
			else { //We're operating without SD card function - don't send anything to sdQueue
				//instead dump the data/send it to sendTask immediately (perhaps as
				//future feature). As of now do nothing and continue to next iteration of loop

			}
		}

		//We assume that all frame packets in a reading buffer are the same size (they come from radar so are uncompressed) - from one reading buffer to the next the size can change.

		//Process reading buffer changes first
		//Check remaining space: rawBufferLen-bytesRead against the framePacketSize


	}
}

int compressor( RADAR_DATA_TYPE* inBuf, size_t inSize, uint32_t* outBuf, uint32_t datalen) {
	size_t bytesWritten = 0;
	uint32_t buf = 0;
	int count = 0;
	uint8_t len;
	int idx, i;
	uint32_t CW;
	int overflow = 0;
	int j = 0;
	size_t ramBufBytes = 0;

//	for (i=0;i<datalen;i++) {
//		if (i%4 == 0) {
//			outBuf[j] = 3;
//			j++;
//			bytesWritten += 4;
//		}
//	}

	for (i=0;i<(datalen);i++) {
		idx = find_code(inBuf[i]);
		len = pCW_len[idx];
		CW = pCW[idx];
		//DEBUG: using fixed codeword and fixed codeword length to try to debug memory error bug
		//len = 10;
		//CW = 603;
		if (32-count-len>=0) {
			//If our next codeword can fit in the current, partially written buffer
			buf = (buf << len);
			buf = buf | CW;
			count += len;
		}
		else {
			if (bytesWritten>(inSize-8)) return -1; //If we're about to write compressed data larger than uncompressed we return -1 to indicate failure.
			overflow = -(32-count-len);
			buf = (buf << (len-overflow));
			buf = (buf | (CW >>overflow));
			//outBuf[j] = buf;
			ramBuf[j] = buf;
			ramBufBytes += 4;
			//bytesWritten += 4;
			j++;
			buf = CW & (0xFFFFFFFF >> (32-overflow));
			count = overflow;

			if (j == ramBufLen) {
				memcpy(outBuf+bytesWritten,ramBuf,ramBufBytes);
				bytesWritten += ramBufBytes;
				ramBufBytes = 0;
				j = 0;
			}

		}

	}

	if (count>0) {
		//outBuf[j] = (buf << (32-count));
		//bytesWritten += 4;
		ramBuf[j] = (buf << (32-count));
		ramBufBytes += 4;
	}

	if (ramBufBytes > 0) {
		memcpy(outBuf+bytesWritten,ramBuf,ramBufBytes);
		bytesWritten += ramBufBytes;
	}

	return bytesWritten;
}

int find_code(float target) {
	int idx = INIT_SEARCH_INDEX;
	float val = *(pBins + idx);
	int temp_index;

	int closest_index = idx;
	float closest_val = 10.0; // Initial estimate is set to a large value so first step of the search improves upon estimate. This should be larger than any value in the encountered data.
	float current_d;
	float closest_d;

	//float target = -0.0001; // must be smaller than whatever closest_val is initialised to,
						   // or the algorithm will return the median idx and assign the target to median value (which isn't the worst outcome if you think about it).

	// Iterate through tree, search
	for (int i = 0; i < NB_INCREMENTS; i++) {

		current_d = target - val;
		closest_d = target - closest_val;

		// Get absolute value
		if (current_d < 0) current_d = 0 - current_d;
		if (closest_d < 0) closest_d = 0 - closest_d;

		if (current_d < closest_d) {  // the current bin is the closest one so far
			closest_val = val;
			closest_index = idx;
		}

		if (target > val) {
			temp_index = idx + *(pIncrements + i);
			if (temp_index > (NB_BINS - 1)) {  // edge case, can happen
				temp_index = (NB_BINS - 1);
			}
			idx = temp_index;

		} else if (target < val) {
			temp_index = idx - *(pIncrements + i);
			if (temp_index < 0) {  // edge case, can happen
				temp_index = 0;
			}
			idx = temp_index;
		}

		val = *(pBins + idx);
	}


	//printf("\n\nTarget val: %f \t Closest idx: %d, Value: %f\n", target, closest_index, *(pBins + closest_index));
	//printf("Associated Codeword: %hu, and Length: %d ", *(pCW + closest_index), *(pCW_len + closest_index));
	return closest_index;
}
