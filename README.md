## Shell script to generate One-Time Passwords

```
usage:  $otp-gen add -n NAME -p PIN -k KEY [ -c COUNTER ]  # add new OTP (replaces existing)
        $otp-gen remove -n NAME                            # remove an existing OTP
        $otp-gen generate -n NAME                          # generate a password
        $otp-gen -h | --help                               # print usage and exit
NAME is the identifier of the OTP you wish to add, remove or generate
PIN is the text that will be prefixed to the generated OTP
KEY is the secret key used to see the OTP algorithm (base32)
COUNTER is the count to store if you are reusing an existing HOTP key
otp-gen will store the generated password on the user's clipboard. If NAME
is not found when generating, the clipboard will be cleared and exit code
will be 2.
```
