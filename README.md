# tm1_application_maintenance_sso
Script to allow calling IBM Cognos TM1 application_maintenance.bat in the environments secured with Cognos BI Single Signon

This Powershell script executes TM1 application maintenance utility with Cognos BI  secured environments with Single Sign-On enabled on webserver. We need to acquire a CAM passport and then call application maintenance bat file with this authentication.
See this IBM technote for more details

Script does the following:
1) Acquires a global mutually exclusive lock (MutEx) to ensure that multiple calls to update applications are serialised and we don't get an 'Another application update job is already running for this application or server' error
2) Logins to Cognos BI portal with provided credentials and grab CAM passport cookie
3) Runs application_maintenance.bat with CAM passport with just got

Call syntax:


Potential improvements:
- Store user credentials in an encrypted string with ConvertTo-SecureString

