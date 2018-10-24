<#
.Synopsis
    Consume an Event Trace Log file (.etl) and convert it to Microsoft Event Viewer log file (.evtx), which can be read from the Event Viewer.
.DESCRIPTION
    This function loads an Event Trace Log file into memory, parses the file and exports each entry in the log to an Event Viewer log file.

    If the specified Event Viewer Log File name does not exist, it is created at runtime. 
    
    Event Viewer Log file names need to be exceptionally unique. This is to say, Windows only looks at the first eight characters of event log names when determining uniqueness. 
.EXAMPLE
    PS> ConvertTo-EvtxLogFormat -EtlFilePath "C:\Windows\System32\winevt\Logs\Microsoft-Windows-DNSServer%4Analytical.etl" -EvtxLogName "DNSServer-Analytical"

    By default, this command produces no output. 
.EXAMPLE
    PS> ConvertTo-EvtxLogFormat -EtlFilePath "C:\Windows\System32\winevt\Logs\Microsoft-Windows-DNSServer%4Analytical.etl" -EvtxLogName "DNSServer-Analytical" -EvtxMaxLogSize 51200 -Verbose

    VERBOSE: Created a new Event Log: 'DNSServer-Analytical'.
    VERBOSE: Applied the following logging limits on 'DNSServer-Analytical' || Size: 51200 | OverflowAction: OverwriteAsNeeded
    VERBOSE: Imported 15964 log entries from: 'C:\Windows\System32\winevt\Logs\Microsoft-Windows-DNSServer%4Analytical.etl'.
    VERBOSE: Added 15964 events to EventLog: 'DNSServer-Analytical'

    This example demonstrates how to impose limits on the log file that gets created.
    It also demonstrates that when the -Verbose flag is specified, descriptive verbose content is returned to the console.
#>
function ConvertTo-EvtxLogFormat {
    [CmdletBinding()]
    param(
        #Specifies a path to an Event Trace Log File (.etl).
        [String] $EtlFilePath,

        #Specifies a name to give to the EVTX log file that gets created at runtime. 
        #If a log file already exists, this parameter specifies that events imported from the .etl file should be written to the specified log file.
        [String] $EvtxLogName,

        #Specifies the maximum size of the .evtx file in kilobytes, as an integer.
        #EvtxMaxLogSize must be between 64KB and 4GB, and the value must be evenly divisible by 64.
        [ValidateScript({ $(($_ % 64) -eq 0) })]
        [ValidateRange(65536, 4294967296)]
        [Int] $EvtxMaxLogSize,

        #Specifies the overflow action that should occur when the log reaches its maximum size.
        #Possible options include overwriting the oldest events (OverwriteAsNeeded) or never overwriting (DoNotOverwrite).
        [ValidateSet('OverwriteAsNeeded','DoNotOverwrite')]
        [String] $EvtxLogOverflowAction = 'OverwriteAsNeeded'
    )

    begin {
        function Import-EtlFile {
            #Helper function to import an ETL file.
            #Returns the contents of the ETL file.
            [CmdletBinding()]
            param(
                #Specifies an event trace log (etl) file to import.
                [ValidateScript({ $_ -match ".etl"})]
                [String] $EtlFilePath
            )

            Begin {
            
            }

            Process {
                #Check for a valid path.
                if (-not (Test-Path $EtlFilePath -ErrorAction SilentlyContinue)) {
                    Write-Error "Cannot find the path '$EltFilePath' because it does not exist." -Category ObjectNotFound
                    return
                }

                #Get the events from the .etl file.
                Try {
                    #-Oldest parameter is required for .etl files.
                    $etlEvents = Get-WinEvent -Path $EtlFilePath -Oldest -Verbose:$false -ErrorAction Stop 

                    return $etlEvents
                }
                Catch {
                    Write-Error "The specified .etl file '$EtlFilePath' could not be read."
                }
            }

            End {

            }
        }    
    }

    process {
        #Create a new event log name/source.
        if (-not (Get-WinEvent -ListLog $EvtxLogName -ErrorAction SilentlyContinue)) {
            Try {
                New-EventLog -Source $EvtxLogName -LogName $EvtxLogName -ErrorAction Stop
                Write-Verbose "Created a new Event Log: '$EvtxLogName'."

                #Set size/retention limits on the EventLog.
                Try {
                    Limit-EventLog -LogName $EvtxLogName -MaximumSize $EvtxMaxLogSize -OverflowAction $EvtxLogOverflowAction -ErrorAction Stop
                    Write-Verbose "Applied the following logging limits on '$EvtxLogName' || Size: $EvtxMaxLogSize | OverflowAction: $EvtxLogOverflowAction"
                }
                Catch {
                    Write-Error "Failed to set logging size/retention limits on event log: '$EvtxLogName'."
                }
            }
            Catch {
                Write-Error "Failed to create a new event log with log name: '$EvtxLogName'. Windows only looks at the first 8 charaters for custom log names. Ensure your log name is unique."
                throw
            }
        }

        #Import all of the events from the ETL file. 
        Try {
            $etlEvents = Import-EtlFile -EtlFilePath $EtlFilePath -ErrorAction Stop
            Write-Verbose "Imported $($etlEvents | Measure-Object | Select-Object -ExpandProperty Count) log entries from: '$EtlFilePath'."
        }
        Catch {
            throw
        }

        #Get the last event in the EVTX event log. If the log is new, there are no events and an error is thrown.
        Try {
            $lastEventGenerated = 'N\A'
            $lastEventGenerated = Get-EventLog -LogName $EvtxLogName -Newest 1 -ErrorAction Stop | 
                Select-Object -ExpandProperty TimeGenerated

            Write-Verbose "The last event written to '$EvtxLogName' occurred on: $lastEventGenerated."
        }
        Catch {
            $lastEventGenerated = (Get-Date "01/01/1600 00:00:00")
        }

        #Loop over events that occurred AFTER the last generated event.
        $eventsToProcess = $etlEvents | 
            Where-Object TimeCreated -gt $lastEventGenerated

        $counter = 0
        if ($eventsToProcess) {
            foreach ($event in $eventsToProcess) {
                $counter++

                $eventlogContents = @"
$($event.Message)

Event ID: $($event.Id)
Event Provider: $($event.ProviderName)
Event Time: $($event.TimeCreated)
Event Level/LevelDisplayName: $($event.Level) / $($event.LevelDisplayName)
Event ComputerName: $($event.MachineName)
Event ProcessID: $($event.ProcessID)
Event UserSID: $($event.UserID)
Event ContainerLog: $($event.ContainerLog)
"@
                
                $writeEventLogSplat = @{
                    LogName = $EvtxLogName
                    Source  = $EvtxLogName
                    EventID = $event.Id
                    Message = $eventlogContents
                }

                Write-EventLog @writeEventLogSplat
            }

            Write-Verbose "Added $counter events to EventLog: '$EvtxLogName'"
        }
        else {
            Write-Verbose "There were no new events to process."
        }        
    }
    
    end {

    }
}