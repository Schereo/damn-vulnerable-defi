# Notes

## Strange response from the server
- The first hex string is: 0x7d15bba26c523683bf3dc77cdc5d1b8a27444471d7cf6da17d5c6f6c9930684d
  - Could a private key because it is 64 characters (32 bytes) long
- The second hex string is: 0x68bd020ad186b647a691c6a5c0fd09dcc45241502ac60ba377c4159
  -  55 characters long, which is not a common length for anything
-  


## Step by step

1. Hex to ASCII
First string

```
4d 48 67 33 5a 44 45 31 59 6d 4a 68 4d 6a 5a 6a 4e 54 49 7a 4e 6a 67 7a 59 6d 5a 6a 4d 32 52 6a 4e 32 4e 6b 59 7a 56 6b 4d 57 49 34 59 54 49 33 4e 44 51 30 4e 44 63 31 4f 54 64 6a 5a 6a 52 6b 59 54 45 33 4d 44 56 6a 5a 6a 5a 6a 4f 54 6b 7a 4d 44 59 7a 4e 7a 51 30
```

```
MHg3ZDE1YmJhMjZjNTIzNjgzYmZjM2RjN2NkYzVkMWI4YTI3NDQ0NDc1OTdjZjRkYTE3MDVjZjZjOTkzMDYzNzQ0
```

Second string:

```
4d 48 67 32 4f 47 4a 6b 4d 44 49 77 59 57 51 78 4f 44 5a 69 4e 6a 51 33 59 54 59 35 4d 57 4d 32 59 54 56 6a 4d 47 4d 78 4e 54 49 35 5a 6a 49 78 5a 57 4e 6b 4d 44 6c 6b 59 32 4d 30 4e 54 49 30 4d 54 51 77 4d 6d 46 6a 4e 6a 42 69 59 54 4d 33 4e 32 4d 30 4d 54 55 35
```

```
MHg2OGJkMDIwYWQxODZiNjQ3YTY5MWM2YTVjMGMxNTI5ZjIxZWNkMDlkY2M0NTI0MTQwMmFjNjBiYTM3N2M0MTU5
```

2. Base64 decode

First string:

```
0x7d15bba26c523683bfc3dc7cdc5d1b8a2744447597cf4da1705cf6c993063744
```

Second string:

```
0x68bd020ad186b647a691c6a5c0c1529f21ecd09dcc45241402ac60ba377c4159
```

32 bytes long, could be a private key

3. Derive public key from private key

First string:

```
0x188Ea627E3531Db590e6f1D71ED83628d1933088
```

Second string:
```
0xA417D473c40a4d42BAd35f147c21eEa7973539D8
```




