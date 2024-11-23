# Script to retrieve cluster node information for multiple servers
# Uses the credentials of the account running the script

# List of servers to check
$Servers = @(
    "EUW1WS009N01",
    "LDN2WS045N02",
    "LDN1WS009N01",
    "LDN1WS029N01",
    "LDN1WS036N01",
    "LDN1WS037N01",
    "LDN1WS039N03",
    "NJC1WS0008N01",
    "njc2ws043n02"
)

# Function to get cluster node information
function Get-ServerClusterNode {
    param([string]$ServerName)
    
    try {
        # Attempt to establish remote PowerShell session using current user's credentials
        $session = New-PSSession -ComputerName $ServerName -ErrorAction Stop
        
        # Get cluster node information
        $clusterNodes = Invoke-Command -Session $session -ScriptBlock {
            try {
                # Try to get cluster nodes using different methods
                $clusterInfo = Get-Cluster -ErrorAction SilentlyContinue
                if ($clusterInfo) {
                    return ($clusterInfo | Get-ClusterNode).Name
                }
                
                # Fallback to alternative method
                $nodes = (Get-WmiObject -Class MSCluster_Node -Namespace root\mscluster -ErrorAction SilentlyContinue)
                if ($nodes) {
                    return $nodes | ForEach-Object { $_.Name }
                }
                
                return "No cluster information found"
            }
            catch {
                return "Error retrieving cluster info: $($_.Exception.Message)"
            }
        }
        
        # Close the remote session
        Remove-PSSession $session
        
        return $clusterNodes
    }
    catch {
        return "Connection failed: $($_.Exception.Message)"
    }
}

# Collect cluster node information
$results = $Servers | ForEach-Object {
    [PSCustomObject]@{
        OriginalServer = $_
        ClusterNodes = (Get-ServerClusterNode -ServerName $_)
    }
}

# Display results in a formatted table
$results | Format-Table -AutoSize

# Optionally, export to CSV for further analysis
$results | Export-Csv -Path ".\ClusterNodeInfo.csv" -NoTypeInformation
