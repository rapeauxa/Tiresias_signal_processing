# -*- coding: utf-8 -*-
"""
Created on Sat Aug 27 16:59:31 2022

Code for creating and searching through the Huffman tree.

@author: Oscar Savolainen
"""

NB_OF_DECODED_VALS = 3  # SET TO HOW MANY VALUES IN A PACKET
MAX_CW_LEN = 21  # SET TO MAXIMUM CODEWORD LENGTH IN HUFFMAN DICT


from Huffman_tree import (
    build_Huffman_tree,
    search_Huffman_tree,  # Not really needed, but useful as demo
    decode_Huffman_string,
    errorIncompleteCodeword,
)


if __name__ == "__main__":

    # Load SH codewords
    CW_file = "stored_SH_461.txt"
    with open(CW_file, "r") as f:
        SH_codewords = f.readlines()
        SH_codewords = [line.rstrip() for line in SH_codewords]

    # Load Bin values/indices/whatever, depends on format we want on server

    bins_file = "stored_bins_461.txt"
    with open(bins_file, "r") as f:
        values = f.readlines()
        values = [line.rstrip() for line in values]

    # Gives int ID to each bin/codeword, useful for debugging
    # values = [
    #     x for x in range(len(SH_codewords))
    # ]  

    # Build the tree from SH codewords and associated values/bins/indices/whatever
    # Run once at beginning of server.
    tree = build_Huffman_tree(SH_codewords, values)
    root = tree[0]  # base of tree, where we begin searches

    # Search Huffman tree. Useful as demo, but only works on individual
    # codewords, not strings of codewords
    CW_index = 211  # Example
    CW = SH_codewords[CW_index]
    value = search_Huffman_tree(CW, root)
    print("Value associated with codeword [", CW, "] is :", value)

    # Works on strings of codewords (padding at end to show it doesn't throw 
    # an error as long as NB_OF_DECODED_VALS is correct)
    CW = SH_codewords[21] + SH_codewords[9] + SH_codewords[145] + "0000000000"
    decoded_vals, error_flag = decode_Huffman_string(
        CW, root, NB_OF_DECODED_VALS, MAX_CW_LEN
    )
    print("Decoded vals:", decoded_vals)
    if error_flag:
        print("Error occured during decode_Huffman_string function:")
        raise errorIncompleteCodeword()
