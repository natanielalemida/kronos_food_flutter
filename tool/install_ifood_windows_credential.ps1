param(
    [Parameter(Mandatory = $true)]
    [string]$CredentialXmlPath
)

$ErrorActionPreference = 'Stop'
$credential = Import-Clixml -LiteralPath $CredentialXmlPath
if ($credential -isnot [pscredential]) {
    throw 'O arquivo precisa conter uma PSCredential protegida pelo Windows.'
}
$clientId = [guid]::Parse($credential.UserName).ToString()
if ($credential.Password.Length -eq 0) {
    throw 'O segredo do aplicativo não pode estar vazio.'
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class KronosIfoodCredentialInstaller {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct Credential {
        public UInt32 Flags;
        public UInt32 Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public UInt32 CredentialBlobSize;
        public IntPtr CredentialBlob;
        public UInt32 Persist;
        public UInt32 AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode,
        SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool Write(ref Credential credential, UInt32 flags);
}
'@

$secretPointer = [Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($credential.Password)
try {
    $entry = [KronosIfoodCredentialInstaller+Credential]::new()
    $entry.Type = 1 # CRED_TYPE_GENERIC
    $entry.TargetName = "KronosFood/iFood/$clientId"
    $entry.UserName = $clientId
    $entry.Comment = 'Aplicativo iFood do Kronos Food'
    $entry.CredentialBlob = $secretPointer
    $entry.CredentialBlobSize = $credential.Password.Length * 2
    $entry.Persist = 2 # Current user, across logon sessions on this computer.
    if (-not [KronosIfoodCredentialInstaller]::Write([ref]$entry, 0)) {
        throw [ComponentModel.Win32Exception]::new([Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
    Write-Output "Credencial iFood instalada para o usuário atual do Windows. Client ID: $clientId"
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($secretPointer)
}
