 connect {
   ca_config {
     #default is 72h. Set this to 1h in order to get rotation after 30-59 minutes.
     leaf_cert_ttl = "1h"
   }
 }