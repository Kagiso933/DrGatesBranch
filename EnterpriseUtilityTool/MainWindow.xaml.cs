using Microsoft.Web.WebView2.Core;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Security.Principal;
using System.Threading.Tasks;
using System.Windows;
using DrGates.Core;

namespace DrGates
{
    public partial class MainWindow : Window
    {
        private readonly ScriptExecutor _scriptExecutor;
        private bool _isAdmin;

        // Admin commands that require elevation
        private readonly string[] _adminCommands = new[]
        {
            "disk_cleanup",
            "temp_files_cleanup",
            "gpupdate",
            "sccm_sync",
            "intune_sync",
            "dns_flush",
            "reset_network",
            "deploy-claudecode"  // Added Claude Code deployment
        };

        public MainWindow()
        {
            InitializeComponent();
            
            Logger.Initialize();
            ConfigurationManager.LoadConfiguration();
            _scriptExecutor = new ScriptExecutor();
            
            // CRITICAL: Subscribe to real-time output events
            _scriptExecutor.OutputLineReceived += OnScriptOutputReceived;
            
            // Auto-enable Branch User Mode for non-admin users
            if (!_isAdmin)
            {
                ConfigurationManager.Config.FeatureFlags.BranchUsersMode = true;
                Logger.Info("Branch User Mode automatically enabled (running as standard user)");
            }

            _isAdmin = CheckAdminPrivileges();
            
            InitializeAsync();
            Closing += (s, e) => Logger.Close();
        }

        private void OnScriptOutputReceived(string output)
        {
            Dispatcher.Invoke(() =>
            {
                try
                {
                    webView?.CoreWebView2?.PostWebMessageAsString(output);
                }
                catch (Exception ex)
                {
                    Logger.Error("Error sending real-time output to web", ex);
                }
            });
        }

        private bool CheckAdminPrivileges()
        {
            try
            {
                using var identity = WindowsIdentity.GetCurrent();
                var principal = new WindowsPrincipal(identity);
                var isAdmin = principal.IsInRole(WindowsBuiltInRole.Administrator);
                Logger.Info($"Admin privileges: {isAdmin}");
                return isAdmin;
            }
            catch (Exception ex)
            {
                Logger.Error("Error checking admin privileges", ex);
                return false;
            }
        }

        private async void InitializeAsync()
        {
            try
            {
                // FIX: Point WebView2 user data to %LOCALAPPDATA% so standard
                // users can write to it. The default (next to the .exe in
                // Program Files) is read-only for non-admins → 0x800700AA.
                var userDataFolder = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "Capitec", "DrGates", "WebView2");

                var environment = await CoreWebView2Environment.CreateAsync(
                    browserExecutableFolder: null,
                    userDataFolder: userDataFolder);

                await webView.EnsureCoreWebView2Async(environment);
                
                webView.CoreWebView2.WebMessageReceived += CoreWebView2_WebMessageReceived;
                
                webView.CoreWebView2.NavigationCompleted += (s, e) =>
                {
                    if (e.IsSuccess)
                    {
                        Logger.Info("WebView2 navigation completed");
                        InitializeWebInterface();
                    }
                    else
                    {
                        Logger.Error($"WebView2 navigation failed: {e.WebErrorStatus}");
                    }
                };

                var htmlPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "WebAssets", "index.html");
                
                if (File.Exists(htmlPath))
                {
                    webView.CoreWebView2.Navigate(new Uri(htmlPath).AbsoluteUri);
                    Logger.Info($"Loading HTML from: {htmlPath}");
                }
                else
                {
                    Logger.Error($"HTML file not found: {htmlPath}");
                    MessageBox.Show($"Interface file not found: {htmlPath}", "Error", 
                        MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
            catch (Exception ex)
            {
                Logger.Error("Error initializing WebView2", ex);
                MessageBox.Show($"Error initializing interface: {ex.Message}", "Error", 
                    MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void InitializeWebInterface()
        {
            try
            {
                var featureFlags = ConfigurationManager.Config.FeatureFlags;
                var config = new
                {
                    isAdmin = _isAdmin,
                    userName = Environment.UserName,
                    machineName = Environment.MachineName,
                    organizationName = ConfigurationManager.Config.OrganizationName,
                    supportEmail = ConfigurationManager.Config.SupportEmail,
                    branchUsersMode = featureFlags.BranchUsersMode,
                    hideDiskCleanup = featureFlags.HideDiskCleanup,
                    hideTempCleanup = featureFlags.HideTempCleanup,
                    hideResetNetwork = featureFlags.HideResetNetwork,
                    hideDeployClaudeCode = featureFlags.HideDeployClaudeCode,
                    hideGPUpdate = featureFlags.HideGPUpdate,
                    hideDNSFlush = featureFlags.HideDNSFlush,
                    showSCCMSync = featureFlags.ShowSCCMSync,
                    showIntuneSyncForAll = featureFlags.ShowIntuneSyncForAll
                };

                var script = $"window.initializeApp({Newtonsoft.Json.JsonConvert.SerializeObject(config)});";
                webView.CoreWebView2.ExecuteScriptAsync(script);
                Logger.Info("Web interface initialized");

                // Send admin status to UI
                SendMessageToWeb("ADMIN_STATUS", _isAdmin.ToString());
            }
            catch (Exception ex)
            {
                Logger.Error("Error initializing web interface", ex);
            }
        }

        private async void CoreWebView2_WebMessageReceived(object sender, CoreWebView2WebMessageReceivedEventArgs args)
        {
            try
            {
                var message = args.WebMessageAsJson.Trim('"');
                Logger.Info($"Received command: {message}");

                // Handle special commands
                if (message == "RESTART_AS_ADMIN")
                {
                    RestartAsAdmin();
                    return;
                }

                if (message == "CHECK_ADMIN_STATUS")
                {
                    SendMessageToWeb("ADMIN_STATUS", _isAdmin.ToString());
                    return;
                }

                var parts = message.Split(new[] { ':' }, 2);
                var command = parts[0];
                var argument = parts.Length > 1 ? parts[1] : string.Empty;

                await HandleCommandAsync(command, argument);
            }
            catch (Exception ex)
            {
                Logger.Error("Error handling web message", ex);
                SendMessageToWeb("log", $"ERROR: {ex.Message}");
            }
        }

        private async Task HandleCommandAsync(string command, string argument)
        {
            var scriptMap = new Dictionary<string, (string script, string targetDiv, bool requiresAdmin)>
            {
                { "check_system_connectivity", ("SystemHealthReport.ps1", "systemHealthOutput", false) },
                { "check_account_status", ("AdUserScript.ps1", "log", false) },
                { "check_network", ("NetworkInfoScript.ps1", "log", false) },
                { "check_zscaler", ("ZscalerInfoScript.ps1", "log", false) },
                { "system_info", ("SystemInfoScript.ps1", "log", false) },
                { "installed_software", ("InstalledApps.ps1", "log", false) },
                { "windows_update_status", ("WindowsUpdates.ps1", "log", false) },
                { "event_log_errors", ("EventLogErrors.ps1", "log", false) },
                { "disk_info", ("DiskInfoScript.ps1", "log", false) },
                { "disk_cleanup", ("DiskCleanupScript.ps1", "log", true) },
                { "temp_files_cleanup", ("TempFilesCleanup.ps1", "log", true) },
                { "view_printers", ("ViewPrinters.ps1", "log", false) },
                { "map_printers", ("MapPrinters.ps1", "log", false) },
                { "gpupdate", ("GPUpdateScript.ps1", "log", true) },
                { "sccm_sync", ("SccmScript.ps1", "log", true) },
                { "teams_cache_clear", ("TeamsCacheScript.ps1", "log", false) },
                { "intune_sync", ("IntuneSyncScript.ps1", "log", true) },
                { "clear_browser_cache", ("ClearBrowserCache.ps1", "log", false) },
                { "network_diagnostics", ("NetworkDiagnostics.ps1", "log", false) },
                { "dns_flush", ("DNSFlush.ps1", "log", true) },
                { "reset_network", ("ResetNetwork.ps1", "log", true) },
                { "performance_report", ("PerformanceReport.ps1", "log", false) },
                { "startup_programs", ("StartupPrograms.ps1", "log", false) },
                { "security_scan", ("SecurityScan.ps1", "log", false) },
                { "clear-all-cache", ("ClearAllCache.ps1", "log", false) },
                { "fix-sso", ("Repair-SSOIssues.ps1", "log", false) },
                { "check-onedrive-backup", ("Test-OneDriveBackup.ps1", "log", false) },
                { "battery-status", ("Get-BatteryStatus.ps1", "log", false) },
                { "create-software-ticket", ("New-SupportTicket.ps1", "log", false) },
                { "create-hardware-ticket", ("New-SupportTicket.ps1", "log", false) },
                { "check_dell_updates", ("Check-DellUpdates.ps1", "log", false) },
                { "install_dell_updates", ("Install-DellUpdates.ps1", "log", true) },
                // Claude Code Deployment - with AutoContinue parameter
                { "deploy-claudecode", ("Run-ClaudeCodeSetup.ps1", "log", true) },
                
                { "check_uptime", ("Get-SystemUptime.ps1", "log", false) }
            };

            if (scriptMap.TryGetValue(command, out var scriptInfo))
            {
                if (scriptInfo.requiresAdmin && !_isAdmin)
                {
                    // Show user-friendly prompt
                    var result = MessageBox.Show(
                        $"The '{GetFriendlyCommandName(command)}' feature requires administrator privileges.\n\n" +
                        "Click 'Yes' to run this command with elevation (UAC prompt will appear).\n" +
                        "Click 'No' to cancel.\n\n" +
                        "💡 Tip: Use 'Run as Administrator' button to elevate entire session.",
                        "Administrator Privileges Required",
                        MessageBoxButton.YesNo,
                        MessageBoxImage.Question);

                    if (result == MessageBoxResult.Yes)
                    {
                        Logger.Info($"User approved elevation for {command}");
                        
                        // Special handling for Claude Code deployment
                        if (command == "deploy-claudecode")
                        {
                            ExecuteElevatedScript(scriptInfo.script, "-AutoContinue");
                        }
                        else
                        {
                            ExecuteElevatedScript(scriptInfo.script, argument);
                        }
                    }
                    else
                    {
                        Logger.Info($"User cancelled elevation for {command}");
                        SendMessageToWeb("log", "⚠️ Command cancelled - administrator privileges required");
                    }
                    return;
                }

                // Execute with AutoContinue for Claude Code deployment
                if (command == "deploy-claudecode")
                {
                    await ExecuteScriptAsync(scriptInfo.script, scriptInfo.targetDiv, "-AutoContinue");
                }
                else
                {
                    await ExecuteScriptAsync(scriptInfo.script, scriptInfo.targetDiv, argument);
                }
            }
            else
            {
                Logger.Warning($"Unknown command: {command}");
                SendMessageToWeb("log", $"ERROR: Unknown command: {command}");
            }
        }

        private void ExecuteElevatedScript(string scriptName, string arguments = "")
        {
            try
            {
                string projectRoot = AppDomain.CurrentDomain.BaseDirectory;
                string scriptPath = Path.Combine(projectRoot, "Scripts", scriptName);

                if (!File.Exists(scriptPath))
                {
                    SendMessageToWeb("log", $"ERROR: Script not found: {scriptPath}");
                    return;
                }

                Logger.Info($"Launching elevated script: {scriptName}");
                SendMessageToWeb("log", $"🔒 Requesting administrator privileges for {Path.GetFileNameWithoutExtension(scriptName)}...");

                // Create elevated PowerShell process
                var startInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{scriptPath}\" {arguments}",
                    Verb = "runas", // This triggers UAC
                    UseShellExecute = true,
                    CreateNoWindow = false // Show window so user sees progress
                };

                var process = Process.Start(startInfo);

                if (process != null)
                {
                    // Monitor completion in background
                    Task.Run(() =>
                    {
                        process.WaitForExit();
                        int exitCode = process.ExitCode;

                        Dispatcher.Invoke(() =>
                        {
                            if (exitCode == 0)
                            {
                                SendMessageToWeb("log", $"✅ {Path.GetFileNameWithoutExtension(scriptName)} completed successfully");
                                Logger.Info($"Elevated script completed: {scriptName}");
                            }
                            else
                            {
                                SendMessageToWeb("log", $"❌ {Path.GetFileNameWithoutExtension(scriptName)} failed (exit code: {exitCode})");
                                Logger.Error($"Elevated script failed: {scriptName} with exit code {exitCode}");
                            }
                        });
                    });
                }
            }
            catch (System.ComponentModel.Win32Exception ex)
            {
                // User cancelled UAC (error code 1223)
                if (ex.NativeErrorCode == 1223)
                {
                    Logger.Info("User cancelled UAC prompt");
                    SendMessageToWeb("log", "⚠️ User cancelled administrator request");
                }
                else
                {
                    Logger.Error($"Elevation failed: {ex.Message}", ex);
                    SendMessageToWeb("log", $"ERROR: Failed to elevate - {ex.Message}");
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Error executing elevated script: {ex.Message}", ex);
                SendMessageToWeb("log", $"ERROR: {ex.Message}");
            }
        }

        private void RestartAsAdmin()
        {
            try
            {
                if (_isAdmin)
                {
                    MessageBox.Show("Application is already running as administrator.",
                        "Information", MessageBoxButton.OK, MessageBoxImage.Information);
                    return;
                }

                Logger.Info("User requested restart as administrator");

                var result = MessageBox.Show(
                    "This will restart Dr Gates with administrator privileges.\n\n" +
                    "All admin-required features will work without additional prompts.\n\n" +
                    "Continue?",
                    "Restart as Administrator",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Question);

                if (result == MessageBoxResult.Yes)
                {
                    var startInfo = new ProcessStartInfo
                    {
                        FileName = Process.GetCurrentProcess().MainModule?.FileName ?? 
                                   System.Reflection.Assembly.GetExecutingAssembly().Location.Replace(".dll", ".exe"),
                        UseShellExecute = true,
                        Verb = "runas" // Request elevation
                    };

                    try
                    {
                        Process.Start(startInfo);
                        Logger.Info("Restarting as administrator - closing current instance");
                        Application.Current.Shutdown();
                    }
                    catch (System.ComponentModel.Win32Exception ex)
                    {
                        if (ex.NativeErrorCode == 1223)
                        {
                            Logger.Info("User cancelled restart as admin");
                            MessageBox.Show("Administrator restart cancelled.",
                                "Information", MessageBoxButton.OK, MessageBoxImage.Information);
                        }
                        else
                        {
                            throw;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to restart as administrator: {ex.Message}", ex);
                MessageBox.Show($"Failed to restart as administrator:\n\n{ex.Message}",
                    "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private string GetFriendlyCommandName(string command)
        {
            return command switch
            {
                "disk_cleanup" => "Disk Cleanup",
                "temp_files_cleanup" => "Temp Files Cleanup",
                "gpupdate" => "Group Policy Update",
                "sccm_sync" => "SCCM Sync",
                "intune_sync" => "Intune Sync",
                "dns_flush" => "DNS Flush",
                "reset_network" => "Network Reset",
                "deploy-claudecode" => "Deploy Claude Code",
                _ => command
            };
        }

        private async Task ExecuteScriptAsync(string scriptName, string targetDiv, string arguments = "")
        {
            SendMessageToWeb("log", $"Executing: {Path.GetFileNameWithoutExtension(scriptName)}...");

            var result = await _scriptExecutor.ExecuteScriptAsync(scriptName, arguments);

            if (result.Success)
            {
                SendMessageToWeb("log", $"✓ Completed in {result.ExecutionTime.TotalSeconds:F2}s");
            }
            else
            {
                SendMessageToWeb("log", $"ERROR: {result.Error}");
            }
        }

        private void SendMessageToWeb(string type, string message)
        {
            try
            {
                var fullMessage = type.Contains(":") ? $"{type}:{message}" : $"{type}: {message}";
                webView.CoreWebView2.PostWebMessageAsString(fullMessage);
            }
            catch (Exception ex)
            {
                Logger.Error("Error sending message to web", ex);
            }
        }
    }
}