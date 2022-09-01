# -*- coding: utf-8 -*-
"""
Created on Sat Aug 27 18:35:59 2022

@author: oscar
"""

from typing import List


# Errors
class Error(Exception):
    """Base class for other exceptions"""

    pass


class errorInvalidCodeword(Error):
    """Raised when the inputed codeword is not a part of the SH dictionary."""

    def __init__(self, CW):
        self.message = f"{CW} does not belong to the SH dictionary."
        super().__init__(self.message)


class errorIncompleteCodeword(Error):
    """Raised when the last part of the string is not assigned to a codeword."""

    def __init__(self):
        message = "End of encoded message not assigned a codeword. The message \
is likely corrupted. Most likely, a bit flip error occured during the \
transmission and the latter part of the message has been corrupted. Noisy \
channel encoding may help prevent this in the future."
        self.message = message
        super().__init__(self.message)


# Used for Huffman tree
class Node:
    def __init__(self, left=None, right=None, index=None):
        self.left = left
        self.right = right
        self.index = (
            index
        )  # default value at node is None, so we know when we have found a leaf node (index not None)


def build_Huffman_tree(SH_codewords: List, values: List) -> List:
    """
    Builds the Huffman tree from the SH codewords. We iterate through each
    codeword, starting at a null node.
    If the next bit is 0, we go left, otherwise, right.
    Once we've reached the end of the codeword, we store the codeword key.
    The only thing we need to be careful of is to not overwrite nodes, so if
    a node is already there (generated while scanning a previous codeword),
    we skip create it again.

    Parameters
    ----------
    SH_codewords : List
        The SH codewords, input as a list of strings.
    values : List
        The values associated with the SH codewords. Should be in the same order
        as the SH codewords.

    Returns
    -------
    List
        Tree containing all of the nodes of the Huffman tree. Searching through
        this tree with a codeword will return the value associated with the
        codeword.

    """

    tree = []
    root = Node()
    tree.append(root)
    for CW_index in range(len(SH_codewords)):
        CW = SH_codewords[CW_index]
        node = root

        for count, i in enumerate(CW):
            if i == "0":
                if not node.left:  # if left child does not exist yet
                    node.left = Node()
                    tree.append(node)
                node = node.left
            elif i == "1":
                if not node.right:
                    node.right = Node()
                    tree.append(node)
                node = node.right

            # Put value associated with codeword at leaf node
            if count == len(CW) - 1:
                node.index = values[CW_index]
                tree.append(node)

    return tree


# NOT NEEDED, BUT MAYBE USEFUL.
def search_Huffman_tree(CW: str, root: Node) -> int:
    """
    Searches through the Huffman tree to get the valkue associated with the codeword.
    I.e., does Huffman decoding.

    Parameters
    ----------
    CW : str
        Huffman codeword entered as a string, beginning with the first bit
        and ending with the last, no whitespaces or special characters, just 1's
        and 0's.
    root : Node
        The root of the Huffman tree, equal to tree[0].

    Returns
    -------
    value: int
        The value assocoiated with the SH codeword. If the codeword is not valid,
        it returns None.

    """

    ## Search Huffman tree
    node = root
    for count, i in enumerate(CW):
        if i == "0":
            if node.left:
                node = node.left
            else:
                raise errorInvalidCodeword
        elif i == "1":
            if node.right:
                node = node.right
            else:
                raise errorInvalidCodeword

        # print(node.index)

    if not node.index == None:
        return node.index
    else:
        return False  # Flag the codeword is not valid


def decode_Huffman_string(
    CW: str, root: Node, NB_OF_DECODED_VALS: int, MAX_CW_LEN: int
) -> List:
    """
    Takes in a binary string, and assigns the codewords to values, i.e.
    does Huffman decoding. If the codewords do not appear on the Huffman tree,
    it throws an error. The error may be because of a bit flip error much earlier on,
    and so may be difficult to diagnose.
    
    It works by iterating through the string, letting the 0's and 1's guide it
    down the tree. Once it reaches an end node, i.e. representing a codeword,
    that codeword's value/key is returned. We then resest some counters, and 
    start aagaina t the top of the tree for the next codeword until the whole
    string is processed.

    Parameters
    ----------
    CW : str
        A collated string of Huffman codewords, entered as a string.
        E.g. bits 0 to 6 correspond to 1 codeword, 7 to 18 to another, etc.
        The lengths of each codeword are not known a priori.
        No whitespaces or special characters, just 1's and 0's.
    root : Node
        The root of the Huffman tree, equal to tree[0].
    NB_OF_DECODED_VALS: int
        We should know how many symbols are expected to be decoded, 
        since the end of the string will be padded with zeros. Once we've 
        decoded as many symbols as expected, we end the decoding of the string.
        Should be a CONSTANT for the whole system.
    MAX_CW_LEN: int
        The maximum codeword length. Used to perform a check to make sure 
        we're decoding a codeword that actually exists.
        Should be a CONSTANT for the whole system.
        

    Returns
    -------
    value: List
        The list of values associated with the string of Huffman codewords.

    """

    # Intitialise
    node = root
    conditions_met = False
    count = 0
    global_count = 0
    decoded_vals = []
    error_flag = False  # Returned if we have a reach-end-of-string type error

    # Until we reach the end of the encoded stirng
    while global_count < len(CW):
        CW_temp = (
            ""
        )  # Store the codeword we are currently decoding. Don't actually need this, but maybe useful for debugging.
        count = 0
        node = root
        while not conditions_met:

            # Update counts
            try:
                i = CW[global_count]
            except:
                error_flag = True
                return decoded_vals, error_flag

            CW_temp += i
            count += 1
            global_count += 1

            if i == "0":
                if node.left:
                    node = node.left
                else:  # This branch of the tree doesn't exist
                    raise errorInvalidCodeword(CW_temp)
            elif i == "1":
                if node.right:
                    node = node.right
                else:  # This branch of the tree doesn't exist
                    raise errorInvalidCodeword(CW_temp)

            if count > MAX_CW_LEN:
                raise errorInvalidCodeword(CW_temp)

            # We end the inner while loop when we find a matching codeword.
            # We then move on to the next codeword.
            # We also end the iner while loop (and then the outer while loop),
            # if we have reached the nu,ber of codewords we were expecting.
            conditions_met = (not node.index == None) or (
                len(decoded_vals) == NB_OF_DECODED_VALS
            )

        if len(decoded_vals) == NB_OF_DECODED_VALS:
            # print("We decoded as many codewords as were expecting (", str(NB_OF_DECODED_VALS), ")")
            break

        decoded_vals.append(node.index)
        conditions_met = False

    return decoded_vals, error_flag
