//------------------------------------------------------------------------------
// <auto-generated>
//     This code was generated from a template.
//
//     Manual changes to this file may cause unexpected behavior in your application.
//     Manual changes to this file will be overwritten if the code is regenerated.
// </auto-generated>
//------------------------------------------------------------------------------

namespace WcfService
{
    using System;
    using System.Collections.Generic;
    
    public partial class Charge
    {
        public int charge_number { get; set; }
        public int invoice_number { get; set; }
        public decimal amount { get; set; }
        public Nullable<System.DateTime> charge_date { get; set; }
    
        public virtual Invoice Invoice { get; set; }
    }
}
