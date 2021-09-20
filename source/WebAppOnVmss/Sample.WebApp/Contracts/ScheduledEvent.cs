using System;
using System.Collections.Generic;
using System.Runtime.Serialization;

namespace Sample.WebApp.Contracts
{
    [DataContract]
    public class ScheduledEventsDocument
    {
        [DataMember]
        public string DocumentIncarnation;

        [DataMember]
        public List<ScheduledEvent> Events { get; set; }
    }

    [DataContract]
    public class ScheduledEvent
    {
        [DataMember]
        public string EventId { get; set; }

        [DataMember]
        public string EventStatus { get; set; }

        [DataMember]
        public string EventType { get; set; }

        [DataMember]
        public string ResourceType { get; set; }

        [DataMember]
        public List<string> Resources { get; set; }

        [DataMember]
        public DateTime? NotBefore { get; set; }
    }

    [DataContract]
    public class ScheduledEventsApproval
    {
        [DataMember]
        public string DocumentIncarnation;

        [DataMember]
        public List<StartRequest> StartRequests = new List<StartRequest>();
    }

    [DataContract]
    public class StartRequest
    {
        [DataMember]
        private string EventId;

        public StartRequest(string eventId)
        {
            this.EventId = eventId;
        }
    }
}
