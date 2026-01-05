# multilib
A sample code base with Multiple Library Setup

## Setup
Run these commands to create the Libraries and Source Physical Files

```
CRTLIB LIB(CMPSYS) TEXT('company system library')
CRTLIB LIB(INVENTORY) TEXT('item inventory library')
CRTSRCPF FILE(INVENTORY/QDDSSRC) RCDLEN(135) TEXT('DDS Sources')
CRTSRCPF FILE(INVENTORY/QRPGLESRC) RCDLEN(135) TEXT('RPGLE Sources')
CRTSRCPF FILE(INVENTORY/QSQLSRC) RCDLEN(135) TEXT('SQL Sources')

CRTSRCPF FILE(CMPSYS/QDDSSRC) RCDLEN(135) TEXT('DDS Sources')
CRTSRCPF FILE(CMPSYS/QRPGLESRC) RCDLEN(135) TEXT('RPGLE Sources')
CRTSRCPF FILE(CMPSYS/QSQLSRC) RCDLEN(135) TEXT('SQL Sources')
```


