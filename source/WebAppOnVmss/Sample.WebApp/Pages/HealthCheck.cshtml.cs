using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Sample.WebApp.Contracts;
using System;
using System.Linq;
using System.Net;
using System.Threading.Tasks;

namespace Sample.WebApp.Pages
{
    public class HealthCheckModel : PageModel
    {
        private readonly ILogger<HealthCheckModel> _logger;
        private readonly IConfiguration _configuration;
        private static DateTime? firstSeenScheduledEvent;

        private readonly string scheduledEventsEndpoint = "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01";
        private readonly string instanceMetadataEndpoint = "http://169.254.169.254/metadata/instance?api-version=2021-05-01";

        public HealthCheckModel(ILogger<HealthCheckModel> logger, IConfiguration configuration)
        {
            this._logger = logger;
            this._configuration = configuration;
        }

        public async Task OnGet()
        {
            // Period between first seeing termination event and approving it.
            TimeSpan gracePeriodSeconds = TimeSpan.FromSeconds(Int32.Parse(_configuration["ScheduledEventsGracePeriodSeconds"]));
            using (WebClient httpClient = new WebClient())
            {
                httpClient.Headers.Add("Metadata", "True");
                string eventsJson = await httpClient.DownloadStringTaskAsync(scheduledEventsEndpoint);
                ScheduledEventsDocument scheduledEventsDocument = JsonConvert.DeserializeObject<ScheduledEventsDocument>(eventsJson);
                if (scheduledEventsDocument.Events?.Count > 0) // there is a scheduled event
                {
                    string[] vmList = scheduledEventsDocument.Events.SelectMany(e => e.Resources).ToArray();
                    string instanceJson = await httpClient.DownloadStringTaskAsync(instanceMetadataEndpoint);
                    InstanceDocument instanceDocument = JsonConvert.DeserializeObject<InstanceDocument>(instanceJson);
                    if (vmList.Contains(instanceDocument.Compute.Name)) // is it for me?
                    {
                        if (firstSeenScheduledEvent == null)
                            firstSeenScheduledEvent = DateTime.UtcNow;
                        else if (DateTime.UtcNow - firstSeenScheduledEvent > gracePeriodSeconds)
                        {
                            // approve it
                            ScheduledEventsApproval approval = new ScheduledEventsApproval()
                            {
                                DocumentIncarnation = scheduledEventsDocument.DocumentIncarnation
                            };
                            var eventsForSelf = scheduledEventsDocument.Events.
                                Where(e => e.Resources.Contains(instanceDocument.Compute.Name));
                            foreach (var anEvent in eventsForSelf)
                            {
                                approval.StartRequests.Add(new StartRequest(anEvent.EventId));
                            }
                            string approveEventsJsonDocument = JsonConvert.SerializeObject(approval);
                            httpClient.Headers.Add("Content-Type", "application/json");
                            httpClient.UploadStringAsync(
                                new Uri(scheduledEventsEndpoint), approveEventsJsonDocument);
                        }
                        // throw an exception for an unhealthy response
                        _logger.LogWarning($"Instance {instanceDocument.Compute.Name} marked for an event, sending unhealthy response");
                        throw new Exception($"Instance {instanceDocument.Compute.Name} marked for an event");
                    }
                }
            }
        }
    }
}