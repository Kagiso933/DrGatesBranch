using Newtonsoft.Json;
using System;
using System.IO;

namespace DrGates.Core
{
    public class AppConfig
    {
        public string OrganizationName { get; set; } = "Capitec Bank";
        public string SupportEmail { get; set; } = "techsupport@capitecbank.co.za";
       // public string SupportPhone { get; set; } = "082-SUPPORT";
        public bool EnableLogging { get; set; } = true;
        public bool EnableTelemetry { get; set; } = false;
        public int ScriptTimeoutSeconds { get; set; } = 300;
        public string[] AdminUsers { get; set; } = Array.Empty<string>();
        public bool RequireAdminForDangerousOperations { get; set; } = true;
        public string CompanyLogoPath { get; set; } = "webassets/logo.png";
        public ScriptSettings Scripts { get; set; } = new ScriptSettings();
    }

    public class ScriptSettings
    {
        public bool AllowGPUpdate { get; set; } = true;
        public bool AllowSCCMSync { get; set; } = true;
        public bool AllowDiskCleanup { get; set; } = true;
        public bool AllowCacheClear { get; set; } = true;
        public bool AllowServiceRestart { get; set; } = true;
        public bool AllowRegistryModification { get; set; } = false;
    }

    public static class ConfigurationManager
    {
        private static AppConfig? _config;
        private static readonly string ConfigPath = Path.Combine(
            AppDomain.CurrentDomain.BaseDirectory,
            "Config",
            "appsettings.json"
        );

        public static AppConfig Config
        {
            get
            {
                if (_config == null)
                    LoadConfiguration();
                return _config!;
            }
        }

        public static void LoadConfiguration()
        {
            try
            {
                if (File.Exists(ConfigPath))
                {
                    var json = File.ReadAllText(ConfigPath);
                    _config = JsonConvert.DeserializeObject<AppConfig>(json) ?? new AppConfig();
                    Logger.Info($"Configuration loaded from {ConfigPath}");
                }
                else
                {
                    _config = new AppConfig();
                    SaveConfiguration();
                    Logger.Warning($"Configuration file not found. Created default at {ConfigPath}");
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Error loading configuration: {ex.Message}", ex);
                _config = new AppConfig();
            }
        }

        public static void SaveConfiguration()
        {
            try
            {
                var configDir = Path.GetDirectoryName(ConfigPath);
                if (!string.IsNullOrEmpty(configDir) && !Directory.Exists(configDir))
                {
                    Directory.CreateDirectory(configDir);
                }

                var json = JsonConvert.SerializeObject(_config, Formatting.Indented);
                File.WriteAllText(ConfigPath, json);
                Logger.Info("Configuration saved");
            }
            catch (Exception ex)
            {
                Logger.Error($"Error saving configuration: {ex.Message}", ex);
            }
        }

        public static bool IsUserAdmin(string username)
        {
            return Config.AdminUsers.Contains(username, StringComparer.OrdinalIgnoreCase);
        }
    }
}
