Inner Product Masking with Robust Error Detection (IPM-RED) countermeasures for AES
======

This is a verilog implementation of the IPM-RED masking scheme as described in [IPM-RED](#references).
We provide an implementation of the arithmetic modules and an IPM-RED masked implementation of the AES-128.

What is implemented
-------------------

* Arithmetic modules for GF8, IPM and IPM-RED
* Protected AES implementations with IPM and IPM-RED countermeasures.

Notes
----

* The AES implementation expects that the key is expanded off-chip. In addition to that, the cipher needs to be supplied with an initial random seed for the build-in RNG. Furthermore, the public parameters and the initial masking of both the plaintext and the expanded key has to be performed off-chip.

References
----------

[IPM-RED] Keren, O., Polian, I. IPM-RED: combining higher-order masking with robust error detection. J Cryptogr Eng 11, 147–160 (2021). https://doi.org/10.1007/s13389-020-00229-4