using Serilog;
using System;
using System.IO;

namespace DrGates.Core
{
    public static class Logger
    {
        private static bool _initialized = false;

        public static void Initialize()
        {
            if (_initialized) return;

            var logPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                "DrGates",
                "Logs",
                "app-log-.txt"
            );

            // Ensure directory exists
            var logDir = Path.GetDirectoryName(logPath);
            if (!string.IsNullOrEmpty(logDir) && !Directory.Exists(logDir))
            {
                Directory.CreateDirectory(logDir);
            }

            Log.Logger = new LoggerConfiguration()
                .MinimumLevel.Debug()
                .WriteTo.File(
                    logPath,
                    rollingInterval: RollingInterval.Day,
                    retainedFileCountLimit: 30,
                    outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}"
                )
                .CreateLogger();

            _initialized = true;
            Log.Information("Application started");
            Log.Information($"User: {Environment.UserName}");
            Log.Information($"Machine: {Environment.MachineName}");
            Log.Information($"OS: {Environment.OSVersion}");
        }

        public static void Info(string message)
        {
            Log.Information(message);
        }

        public static void Warning(string message)
        {
            Log.Warning(message);
        }

        public static void Error(string message, Exception? ex = null)
        {
            if (ex != null)
                Log.Error(ex, message);
            else
                Log.Error(message);
        }

        public static void Debug(string message)
        {
            Log.Debug(message);
        }

        public static void LogScriptExecution(string scriptName, bool success, string output = "")
        {
            if (success)
            {
                Log.Information($"Script executed successfully: {scriptName}");
                if (!string.IsNullOrEmpty(output))
                    Log.Debug($"Script output: {output}");
            }
            else
            {
                Log.Error($"Script execution failed: {scriptName}. Output: {output}");
            }
        }

        public static void Close()
        {
            Log.Information("Application closing");
            Log.CloseAndFlush();
        }
    }
}
