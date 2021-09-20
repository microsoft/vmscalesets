using System.Runtime.Serialization;

namespace Sample.WebApp.Contracts
{
    [DataContract]
    public class InstanceDocument
    {
        [DataMember]
        public Compute Compute { get; set; }
    }

    [DataContract]
    public class Compute
    {
        [DataMember]
        public string Name { get; set; }
    }
}
