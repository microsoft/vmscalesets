using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Logging;
using System;
using System.Diagnostics;
using System.Threading.Tasks;

namespace Sample.WebApp.Pages
{
    public class IndexModel : PageModel
    {
        public string MachineName { get; private set; }
        public string RemoteIp { get; private set; }

        private readonly ILogger<IndexModel> _logger;

        public IndexModel(ILogger<IndexModel> logger)
        {
            _logger = logger;
        }

        public void OnGet(int milliseconds)
        {
            Parallel.For(0, Environment.ProcessorCount, new ParallelOptions
            {
                MaxDegreeOfParallelism = Environment.ProcessorCount
            }, (Action<int>)delegate
            {
                Stopwatch stopwatch = Stopwatch.StartNew();
                while (stopwatch.ElapsedMilliseconds < milliseconds)
                {
                }
                this.MachineName = Environment.MachineName;
                this.RemoteIp = base.Request.HttpContext.Connection.RemoteIpAddress?.ToString();
            });
            _logger.LogInformation($"{MachineName} processing took {milliseconds}");
        }
    }
}
