# Remove all WinRM Listeners
## https://docs.ansible.com/ansible/2.5/user_guide/windows_setup.html#delete-winrm-listener
Remove-Item -Path WSMan:\localhost\Listener\* -Recurse -Force