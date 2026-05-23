@{
    RootModule = 'PSRokuCreate.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'd1b1b871-07f6-4184-bb5b-98ebdbc2511f'
    Author = 'Marc Newhard'
    Copyright = '(c) 2025 Marc Newhard. Licensed under the MIT License.'
    Description = 'Scaffolds new Roku channel projects, with SSDP device discovery and side-load support.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('New-RokuProject', 'Find-RokuDevice', 'Get-RokuDeviceInfo', 'Send-RokuApp')
    CmdletsToExport = @()
    AliasesToExport = @()
    VariablesToExport = @()
}
