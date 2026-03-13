using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace DrGates.Core
{
    public class ScriptExecutionResult
    {
        public bool Success { get; set; }
        public string Output { get; set; } = string.Empty;
        public string Error { get; set; } = string.Empty;
        public int ExitCode { get; set; }
        public TimeSpan ExecutionTime { get; set; }
    }

    public class ScriptExecutor
    {
        private readonly int _timeoutSeconds;

        //  Event to send output lines in real-time
        public event Action<string> OutputLineReceived;

        public ScriptExecutor()
        {
            _timeoutSeconds = ConfigurationManager.Config.ScriptTimeoutSeconds;
        }

        public async Task<ScriptExecutionResult> ExecuteScriptAsync(string scriptName, string arguments = "")
        {
            var stopwatch = Stopwatch.StartNew();
            var result = new ScriptExecutionResult();

            string projectRoot = AppDomain.CurrentDomain.BaseDirectory;
            string scriptPath = Path.Combine(projectRoot, "Scripts", scriptName);

            Logger.Info($"Executing script: {scriptName} with arguments: {arguments}");

            if (!File.Exists(scriptPath))
            {
                result.Success = false;
                result.Error = $"Script file not found: {scriptPath}";
                Logger.Error(result.Error);
                return result;
            }

            try
            {
                var startInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = BuildArguments(scriptPath, arguments),
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true,
                    StandardOutputEncoding = Encoding.UTF8,
                    StandardErrorEncoding = Encoding.UTF8
                };

                using var process = new Process { StartInfo = startInfo };
                var outputBuilder = new StringBuilder();
                var errorBuilder = new StringBuilder();

                process.OutputDataReceived += (sender, e) =>
                {
                    if (e.Data != null)
                    {
                        //  Send line immediately to UI
                        OutputLineReceived?.Invoke(e.Data);

                        //  Filter STATUS_UPDATE lines from final output
                        if (!e.Data.StartsWith("STATUS_UPDATE:"))
                        {
                            outputBuilder.AppendLine(e.Data);
                        }
                    }
                };

                process.ErrorDataReceived += (sender, e) =>
                {
                    if (e.Data != null)
                    {
                        //  Send errors immediately too
                        OutputLineReceived?.Invoke($"ERROR: {e.Data}");
                        errorBuilder.AppendLine(e.Data);
                    }
                };

                process.Start();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();

                // Wait for completion with timeout
                using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(_timeoutSeconds));
                try
                {
                    await process.WaitForExitAsync(cts.Token);
                }
                catch (OperationCanceledException)
                {
                    process.Kill();
                    result.Success = false;
                    result.Error = $"Script execution timed out after {_timeoutSeconds} seconds";
                    Logger.Error(result.Error);
                    return result;
                }

                stopwatch.Stop();
                result.ExecutionTime = stopwatch.Elapsed;
                result.Output = outputBuilder.ToString().Trim();
                result.Error = errorBuilder.ToString().Trim();
                result.ExitCode = process.ExitCode;
                result.Success = process.ExitCode == 0 && string.IsNullOrEmpty(result.Error);

                Logger.LogScriptExecution(scriptName, result.Success, 
                    result.Success ? result.Output : result.Error);
            }
            catch (Exception ex)
            {
                stopwatch.Stop();
                result.Success = false;
                result.Error = $"Exception occurred: {ex.Message}";
                result.ExecutionTime = stopwatch.Elapsed;
                Logger.Error($"Script execution error: {scriptName}", ex);
            }

            return result;
        }

        private string BuildArguments(string scriptPath, string arguments)
        {
            var args = $"-NoProfile -ExecutionPolicy Bypass -File \"{scriptPath}\"";
            if (!string.IsNullOrEmpty(arguments))
                args += $" {arguments}";
            return args;
        }

        public static bool ValidateScriptName(string scriptName)
        {
            // Prevent path traversal and ensure safe script name
            return !string.IsNullOrEmpty(scriptName) &&
                   !scriptName.Contains("..") &&
                   !scriptName.Contains("/") &&
                   !scriptName.Contains("\\") &&
                   scriptName.EndsWith(".ps1", StringComparison.OrdinalIgnoreCase);
        }
    }
}