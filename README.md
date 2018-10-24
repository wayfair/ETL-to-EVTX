## Example Usage

The following example converts the contents of the 'Microsoft\Windows\DNS-Server\Analytical' event trace log into an EVTX log format at the point in time the function was called.

If the Event Log "DNSServer-Analytical" does not exist, it is created at runtime. Likewise, circular logging is enabled, and the logsize is set to 512000 KB 

```
ConvertTo-EvtxLogFormat `
    -EtlFilePath "C:\Windows\System32\winevt\Logs\Microsoft-Windows-DNSServer%4Analytical.etl" `
    -EvtxLogName "DNSServer-Analytical"
```


The following example calls ConvertTo-EvtxLogFormat every 30 seconds adding any log entries that are not already written to "DNSServer-Analytical" log file.
The example also demonstrates changing the Event Log Max Size to 51200 KB (50 MB).

This code sample should be considered "proof-of-concept". You might see performance degradation on your server if you run the code in a loop 24/7/365. It might make more sense to run the previous example as a scheduled task at a desired frequency. This should prevent memory allocation buildup. 

```
while ($true) {
    ConvertTo-EvtxLogFormat `
        -EtlFilePath "C:\Windows\System32\winevt\Logs\Microsoft-Windows-DNSServer%4Analytical.etl" `
        -EvtxLogName "DNSServer-Analytical" `
        -EvtxMaxLogSize 51200 `
        -Verbose

    Start-Sleep -Seconds 30
}
```

## Sample Verbose Output

```
VERBOSE: Created a new Event Log: 'DNSServer-Analytical'.
VERBOSE: Imposed the following limits on 'DNSServer-Analytical' || Size(KB): 524288 | OverflowAction: OverwriteAsNeeded
VERBOSE: Imported 15964 log entries from: 'C:\Windows\System32\winevt\Logs\Microsoft-Windows-DNSServer%4Analytical.etl'.
VERBOSE: Added 15964 events to EventLog: 'DNSServer-Analytical'
VERBOSE: Imported 16539 log entries from: 'C:\Windows\System32\winevt\Logs\Microsoft-Windows-DNSServer%4Analytical.etl'.
VERBOSE: The last event written to 'DNSServer-Analytical' occurred on: 10/16/2018 16:27:47.
VERBOSE: Added 73 events to EventLog: 'DNSServer-Analytical'
VERBOSE: Imported 16775 log entries from: 'C:\Windows\System32\winevt\Logs\Microsoft-Windows-DNSServer%4Analytical.etl'.
VERBOSE: The last event written to 'DNSServer-Analytical' occurred on: 10/16/2018 16:28:45.
VERBOSE: Added 50 events to EventLog: 'DNSServer-Analytical'
```
