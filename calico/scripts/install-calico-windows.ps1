# Copyright (c) 2020-2021 Tigera, Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

<#
.DESCRIPTION
    This script installs and starts Calico services on a Windows node.

    Note: EKS requires downloading kubectl.exe to c:\k before running this script: https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
#>

Param(
    # Note: we don't publish a release artifact for the "master" branch. To test
    # against master, build calico-windows.zip from projectcalico/node.
    [parameter(Mandatory = $false)] $ReleaseBaseURL="https://github.com/projectcalico/calico/releases/download/master/",
    [parameter(Mandatory = $false)] $ReleaseFile="calico-windows-master.zip",
    [parameter(Mandatory = $false)] $KubeVersion="",
    [parameter(Mandatory = $false)] $DownloadOnly="no",
    [parameter(Mandatory = $false)] $Datastore="kubernetes",
    [parameter(Mandatory = $false)] $EtcdEndpoints="",
    [parameter(Mandatory = $false)] $EtcdTlsSecretName="",
    [parameter(Mandatory = $false)] $EtcdKey="",
    [parameter(Mandatory = $false)] $EtcdCert="",
    [parameter(Mandatory = $false)] $EtcdCaCert="",
    [parameter(Mandatory = $false)] $ServiceCidr="10.96.0.0/12",
    [parameter(Mandatory = $false)] $DNSServerIPs="10.96.0.10",
    [parameter(Mandatory = $false)] $CalicoBackend=""
)

function DownloadFiles()
{
    Write-Host "Creating CNI directory"
    md $BaseDir\cni\config -ErrorAction Ignore

    Write-Host "Downloading Windows Kubernetes scripts"
    DownloadFile -Url  https://github.com/Microsoft/SDN/raw/master/Kubernetes/windows/hns.psm1 -Destination $BaseDir\hns.psm1
    DownloadFile -Url  https://github.com/Microsoft/SDN/raw/master/Kubernetes/windows/InstallImages.ps1 -Destination $BaseDir\InstallImages.ps1
    DownloadFile -Url  https://github.com/Microsoft/SDN/raw/master/Kubernetes/windows/Dockerfile -Destination $BaseDir\Dockerfile
}

function PrepareDockerFile()
{
    # Update Dockerfile for windows
    $OSInfo = (Get-ComputerInfo  | select WindowsVersion, OsBuildNumber)
    $OSNumber = $OSInfo.WindowsVersion
    $ExistOSNumber = cat c:\k\Dockerfile | findstr.exe $OSNumber
    if (!$ExistOSNumber)
    {
        Write-Host "Update dockerfile for $OSNumber"

        $ImageWithOSNumber = "nanoserver:" + $OSNumber
        (get-content c:\k\Dockerfile) | foreach-object {$_ -replace "nanoserver", "$ImageWithOSNumber"} | set-content c:\k\Dockerfile
    }
}

function PrepareKubernetes()
{
    DownloadFiles
    PrepareDockerFile
    ipmo C:\k\hns.psm1

    # Prepare POD infra Images
    c:\k\InstallImages.ps1

    InstallK8sBinaries
}

function InstallK8sBinaries()
{
    Install-7Zip
    $Source = "" | Select Release
    $Source.Release=$KubeVersion
    InstallKubernetesBinaries -Destination $BaseDir -Source $Source
    cp c:\k\kubernetes\node\bin\*.exe c:\k
}

function GetPlatformType()
{
    # AKS
    $hnsNetwork = Get-HnsNetwork | ? Name -EQ azure
    if ($hnsNetwork.name -EQ "azure") {
        return ("aks")
    }

    # EKS
    $hnsNetwork = Get-HnsNetwork | ? Name -like "vpcbr*"
    if ($hnsNetwork.name -like "vpcbr*") {
        return ("eks")
    }

    # EC2
    $restError = $null
    Try {
        $awsNodeName=Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/local-hostname -ErrorAction Ignore
    } Catch {
        $restError = $_
    }
    if ($restError -eq $null) {
        return ("ec2")
    }

    # GCE
    $restError = $null
    Try {
        $gceNodeName = Invoke-RestMethod -UseBasicParsing -Headers @{"Metadata-Flavor"="Google"} "http://metadata.google.internal/computeMetadata/v1/instance/hostname" -ErrorAction Ignore
    } Catch {
        $restError = $_
    }
    if ($restError -eq $null) {
        return ("gce")
    }

    return ("bare-metal")
}

function GetBackendType()
{
    param(
        [parameter(Mandatory=$true)] $CalicoNamespace,
        [parameter(Mandatory=$false)] $KubeConfigPath = "$RootDir\calico-kube-config"
    )

    if (-Not [string]::IsNullOrEmpty($CalicoBackend)) {
        return $CalicoBackend
    }

    # Auto detect backend type
    if ($Datastore -EQ "kubernetes") {
        $encap=c:\k\kubectl.exe --kubeconfig="$RootDir\calico-kube-config" get felixconfigurations.crd.projectcalico.org default -o jsonpath='{.spec.ipipEnabled}' -n $CalicoNamespace
        if ($encap -EQ "true") {
            throw "Calico on Linux has IPIP enabled. IPIP is not supported on Windows nodes."
        }

        $encap=c:\k\kubectl.exe --kubeconfig="$RootDir\calico-kube-config" get felixconfigurations.crd.projectcalico.org default -o jsonpath='{.spec.vxlanEnabled}' -n $CalicoNamespace
        if ($encap -EQ "true") {
            return ("vxlan")
        }
        return ("bgp")
    } else {
        $CalicoBackend=c:\k\kubectl.exe --kubeconfig="$RootDir\calico-kube-config" get configmap calico-config -n $CalicoNamespace -o jsonpath='{.data.calico_backend}'
        if ($CalicoBackend -EQ "vxlan") {
            return ("vxlan")
        }
        return ("bgp")
    }
}

function GetCalicoNamespace() {
    param(
      [parameter(Mandatory=$false)] $KubeConfigPath = "c:\\k\\config"
    )

    $name=c:\k\kubectl.exe --kubeconfig=$KubeConfigPath get ns calico-system
    if ([string]::IsNullOrEmpty($name)) {
        write-host "Calico running in kube-system namespace"
        return ("kube-system")
    }
    write-host "Calico running in calico-system namespace"
    return ("calico-system")
}

function GetCalicoKubeConfig()
{
    param(
      [parameter(Mandatory=$true)] $CalicoNamespace,
      [parameter(Mandatory=$false)] $SecretName = "calico-node",
      [parameter(Mandatory=$false)] $KubeConfigPath = "c:\\k\\config"
    )

    # On EKS, we need to have AWS tools loaded for kubectl authentication.
    $eksAWSToolsModulePath="C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"
    if (Test-Path $eksAWSToolsModulePath) {
        Write-Host "AWSPowerShell module exists, loading $eksAWSToolsModulePath ..."
        Import-Module $eksAWSToolsModulePath
    }

    $name=c:\k\kubectl.exe --kubeconfig=$KubeConfigPath get secret -n $CalicoNamespace --field-selector=type=kubernetes.io/service-account-token --no-headers -o custom-columns=":metadata.name" | findstr $SecretName | select -first 1
    if ([string]::IsNullOrEmpty($name)) {
        throw "$SecretName service account does not exist."
    }
    $ca=c:\k\kubectl.exe --kubeconfig=$KubeConfigPath get secret/$name -o jsonpath='{.data.ca\.crt}' -n $CalicoNamespace
    $tokenBase64=c:\k\kubectl.exe --kubeconfig=$KubeConfigPath get secret/$name -o jsonpath='{.data.token}' -n $CalicoNamespace
    $token=[System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($tokenBase64))

    $server=findstr https:// $KubeConfigPath

    (Get-Content $RootDir\calico-kube-config.template).replace('<ca>', $ca).replace('<server>', $server.Trim()).replace('<token>', $token) | Set-Content $RootDir\calico-kube-config -Force
}

function EnableWinDsrForEKS()
{
    $OSInfo = (Get-ComputerInfo  | select WindowsVersion, OsBuildNumber)
    $PlatformSupportDSR = (($OSInfo.WindowsVersion -as [int]) -GE 1903 -And ($OSInfo.OsBuildNumber -as [int]) -GE 18317)

    if (-Not $PlatformSupportDSR) {
        Write-Host "WinDsr is not supported ($OSInfo)"
        return
    }

    # Update and restart kube-proxy if WinDSR is not enabled by default.
    $Path = Get-CimInstance -Query 'select * from win32_service where name="kube-proxy"' | Select -ExpandProperty pathname
    if ($Path -like "*--enable-dsr=true*") {
        Write-Host "WinDsr is enabled by default."
    } else {
        $UpdatedPath = $Path + " --enable-dsr=true --feature-gates=WinDSR=true"
        Get-CimInstance win32_service -filter 'Name="kube-proxy"' | Invoke-CimMethod -Name Change -ArgumentList @($null,$null,$null,$null,$null,$UpdatedPath)
        Restart-Service -name "kube-proxy"
        Write-Host "WinDsr has been enabled for kube-proxy."
    }
}

function SetupEtcdTlsFiles()
{
    param(
      [parameter(Mandatory=$true)] $CalicoNamespace,
      [parameter(Mandatory=$true)] $SecretName,
      [parameter(Mandatory=$false)] $KubeConfigPath = "c:\\k\\config"
    )

    $path = "$RootDir\etcd-tls"

    $found=c:\k\kubectl.exe --kubeconfig=$KubeConfigPath get secret/$SecretName -n $CalicoNamespace
    if ([string]::IsNullOrEmpty($found)) {
        throw "$SecretName does not exist."
    }

    $keyB64=c:\k\kubectl.exe --kubeconfig=$KubeConfigPath get secret/$SecretName -o jsonpath='{.data.etcd-key}' -n $CalicoNamespace
    $certB64=c:\k\kubectl.exe --kubeconfig=$KubeConfigPath get secret/$SecretName -o jsonpath='{.data.etcd-cert}' -n $CalicoNamespace
    $caB64=c:\k\kubectl.exe --kubeconfig=$KubeConfigPath get secret/$SecretName -o jsonpath='{.data.etcd-ca}' -n $CalicoNamespace

    New-Item -Type Directory -Path $path -Force

    [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($keyB64)) | Set-Content "$path\server.key" -Force
    [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($certB64)) | Set-Content "$path\server.crt" -Force
    [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($caB64)) | Set-Content "$path\ca.crt" -Force

    $script:EtcdKey = "$path\server.key"
    $script:EtcdCert = "$path\server.crt"
    $script:EtcdCaCert = "$path\ca.crt"
}

function SetConfigParameters {
    param(
        [parameter(Mandatory=$true)] $OldString,
        [parameter(Mandatory=$true)] $NewString
    )

    (Get-Content $RootDir\config.ps1).replace($OldString, $NewString) | Set-Content $RootDir\config.ps1 -Force
}

function SetAKSCalicoStaticRules {
    $fileName  = [Io.path]::Combine("$RootDir", "static-rules.json")
    echo '{
    "Provider": "AKS",
    "Rules": [
        {
            "Name": "EndpointPolicy",
            "Rule": {
                "Action": "Block",
                "Direction": "Out",
                "Id": "block-wireserver",
                "Priority": 200,
                "Protocol": 6,
                "RemoteAddresses": "168.63.129.16/32",
                "RemotePorts": "80",
                "RuleType": "Switch",
                "Type": "ACL"
            }
        }
    ],
    "version": "0.1.0"
}' | Out-File -encoding ASCII -filepath $fileName
}

function StartCalico()
{
    Write-Host "`nStart Calico for Windows...`n"

    pushd
    cd $RootDir
    .\install-calico.ps1
    popd
    Write-Host "`nCalico for Windows Started`n"
}

$BaseDir="c:\k"
$RootDir="c:\CalicoWindows"
$CalicoZip="c:\calico-windows.zip"

# Must load the helper modules before doing anything else.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$helper = "$BaseDir\helper.psm1"
$helperv2 = "$BaseDir\helper.v2.psm1"
md $BaseDir -ErrorAction Ignore
if (!(Test-Path $helper))
{
    Invoke-WebRequest https://raw.githubusercontent.com/Microsoft/SDN/master/Kubernetes/windows/helper.psm1 -O $BaseDir\helper.psm1
}
if (!(Test-Path $helperv2))
{
    Invoke-WebRequest https://raw.githubusercontent.com/Microsoft/SDN/master/Kubernetes/windows/helper.v2.psm1 -O $BaseDir\helper.v2.psm1
}
ipmo -force $helper
ipmo -force $helperv2

if (!(Test-Path $CalicoZip))
{
    Write-Host "$CalicoZip not found, downloading Calico for Windows release..."
    DownloadFile -Url $ReleaseBaseURL/$ReleaseFile -Destination c:\calico-windows.zip
}

$platform=GetPlatformType

if (-Not [string]::IsNullOrEmpty($KubeVersion) -and $platform -NE "eks") {
    PrepareKubernetes
}

if ((Get-Service -exclude 'CalicoUpgrade' | where Name -Like 'Calico*' | where Status -EQ Running) -NE $null) {
Write-Host "Calico services are still running. In order to re-run the installation script, stop the CalicoNode and CalicoFelix services or uninstall them by running: $RootDir\uninstall-calico.ps1"
Exit
}

Remove-Item $RootDir -Force  -Recurse -ErrorAction SilentlyContinue
Write-Host "Unzip Calico for Windows release..."
Expand-Archive -Force $CalicoZip c:\

Write-Host "Setup Calico for Windows..."
SetConfigParameters -OldString '<your datastore type>' -NewString $Datastore
SetConfigParameters -OldString '<your etcd endpoints>' -NewString "$EtcdEndpoints"

if (-Not [string]::IsNullOrEmpty($EtcdTlsSecretName)) {
    $calicoNs = GetCalicoNamespace
    SetupEtcdTlsFiles -SecretName "$EtcdTlsSecretName" -CalicoNamespace $calicoNs
}
SetConfigParameters -OldString '<your etcd key>' -NewString "$EtcdKey"
SetConfigParameters -OldString '<your etcd cert>' -NewString "$EtcdCert"
SetConfigParameters -OldString '<your etcd ca cert>' -NewString "$EtcdCaCert"
SetConfigParameters -OldString '<your service cidr>' -NewString $ServiceCidr
SetConfigParameters -OldString '<your dns server ips>' -NewString $DNSServerIPs

if ($platform -EQ "aks") {
    Write-Host "Setup Calico for Windows for AKS..."
    $Backend="none"
    SetConfigParameters -OldString 'CALICO_NETWORKING_BACKEND="vxlan"' -NewString 'CALICO_NETWORKING_BACKEND="none"'
    SetConfigParameters -OldString 'KUBE_NETWORK = "Calico.*"' -NewString 'KUBE_NETWORK = "azure.*"'

    $calicoNs = "calico-system"
    GetCalicoKubeConfig -CalicoNamespace $calicoNs

    SetAKSCalicoStaticRules
}
if ($platform -EQ "eks") {
    EnableWinDsrForEKS

    $token = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "300"} -Method PUT -Uri http://169.254.169.254/latest/api/token -ErrorAction Ignore
    $awsNodeName = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token" = $token} -Method GET -Uri http://169.254.169.254/latest/meta-data/local-hostname -ErrorAction Ignore
    Write-Host "Setup Calico for Windows for EKS, node name $awsNodeName ..."
    $Backend = "none"
    $awsNodeNameQuote = """$awsNodeName"""
    SetConfigParameters -OldString '$(hostname).ToLower()' -NewString "$awsNodeNameQuote"
    SetConfigParameters -OldString 'CALICO_NETWORKING_BACKEND="vxlan"' -NewString 'CALICO_NETWORKING_BACKEND="none"'
    SetConfigParameters -OldString 'KUBE_NETWORK = "Calico.*"' -NewString 'KUBE_NETWORK = "vpc.*"'

    $calicoNs = GetCalicoNamespace -KubeConfigPath C:\ProgramData\kubernetes\kubeconfig
    GetCalicoKubeConfig -CalicoNamespace $calicoNs -KubeConfigPath C:\ProgramData\kubernetes\kubeconfig
}
if ($platform -EQ "ec2") {
    $token = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "300"} -Method PUT -Uri http://169.254.169.254/latest/api/token -ErrorAction Ignore
    $awsNodeName = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token" = $token} -Method GET -Uri http://169.254.169.254/latest/meta-data/local-hostname -ErrorAction Ignore
    Write-Host "Setup Calico for Windows for AWS, node name $awsNodeName ..."
    $awsNodeNameQuote = """$awsNodeName"""
    SetConfigParameters -OldString '$(hostname).ToLower()' -NewString "$awsNodeNameQuote"

    $calicoNs = GetCalicoNamespace
    GetCalicoKubeConfig -CalicoNamespace $calicoNs
    $Backend = GetBackendType -CalicoNamespace $calicoNs

    Write-Host "Backend networking is $Backend"
    if ($Backend -EQ "bgp") {
        SetConfigParameters -OldString 'CALICO_NETWORKING_BACKEND="vxlan"' -NewString 'CALICO_NETWORKING_BACKEND="windows-bgp"'
    }
}
if ($platform -EQ "gce") {
    $gceNodeName = Invoke-RestMethod -UseBasicParsing -Headers @{"Metadata-Flavor"="Google"} "http://metadata.google.internal/computeMetadata/v1/instance/hostname" -ErrorAction Ignore
    Write-Host "Setup Calico for Windows for GCE, node name $gceNodeName ..."
    $gceNodeNameQuote = """$gceNodeName"""
    SetConfigParameters -OldString '$(hostname).ToLower()' -NewString "$gceNodeNameQuote"

    $calicoNs = GetCalicoNamespace
    GetCalicoKubeConfig -CalicoNamespace $calicoNs
    $Backend = GetBackendType -CalicoNamespace $calicoNs

    Write-Host "Backend networking is $Backend"
    if ($Backend -EQ "bgp") {
        SetConfigParameters -OldString 'CALICO_NETWORKING_BACKEND="vxlan"' -NewString 'CALICO_NETWORKING_BACKEND="windows-bgp"'
    }
}
if ($platform -EQ "bare-metal") {
    $calicoNs = GetCalicoNamespace
    GetCalicoKubeConfig -CalicoNamespace $calicoNs
    $Backend = GetBackendType -CalicoNamespace $calicoNs

    Write-Host "Backend networking is $Backend"
    if ($Backend -EQ "bgp") {
        SetConfigParameters -OldString 'CALICO_NETWORKING_BACKEND="vxlan"' -NewString 'CALICO_NETWORKING_BACKEND="windows-bgp"'
    }
}

if ($DownloadOnly -EQ "yes") {
    Write-Host "Downloaded Calico for Windows. Update c:\CalicoWindows\config.ps1 and run c:\CalicoWindows\install-calico.ps1"
    Exit
}

StartCalico

if ($Backend -NE "none") {
    New-NetFirewallRule -Name KubectlExec10250 -Description "Enable kubectl exec and log" -Action Allow -LocalPort 10250 -Enabled True -DisplayName "kubectl exec 10250" -Protocol TCP -ErrorAction SilentlyContinue
}
