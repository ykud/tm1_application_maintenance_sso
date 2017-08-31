# tm1_application_maintenance_sso
Script to allow calling IBM Cognos TM1 application_maintenance.bat in the environments secured with Cognos BI Single Signon

This Powershell script executes TM1 application maintenance utility with Cognos BI  secured environments with Single Sign-On enabled on webserver. We need to acquire a CAM passport and then call application maintenance bat file with this authentication.
See this IBM technote for more details
https://www-304.ibm.com/support/entdocview.wss?uid=swg1PI11160
and my original post
http://ykud.com/blog/cognos/tm1-cognos/tm1-application-maintenance-utility-and-singlesignon


Script does the following:
1) Acquires a global mutually exclusive lock (MutEx) to ensure that multiple calls to update applications are serialised and we don't get an 'Another application update job is already running for this application or server' error
2) Logins to Cognos BI portal with provided credentials and grab CAM passport cookie
3) Runs application_maintenance.bat with CAM passport with just got

Call syntax:
powershell.exe "path\tm1_application_maintenance_sso.ps1" "log_folder\" "cognos_bi_gateway" 'AD Namespace' "user" "password" 'path_to_app_maintenance.bat' tm1_application_server  'Application Name'  importrights  'rights_file'

powershell.exe "path\tm1_application_maintenance_sso.ps1" "log_folder\" http://your_cognos_bi_gateway 'AD Namespace' "user" "password" 'C:\Program Files\ibm\cognos\tm1_64\webapps\pmpsvc\WEB-INF\tools\' http://tm1_apllication_server:9510/pmpsvc  'Application Name'  importrights  'rights_file'

Potential improvements:
- Store user credentials in an encrypted string with ConvertTo-SecureString

