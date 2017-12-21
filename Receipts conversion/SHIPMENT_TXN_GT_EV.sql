-- +===================================================================================+
-- | Index Name : SHIPMENT_TXN_GT_EV                                         		   |
-- | Script Name: SHIPMENT_TXN_GT_EV.sql                                     		   |
-- | Description: Editioning View on the SHIPMENT_TXN_GT table               		   |
-- |                                                                                   |
-- |                                                                                   |
-- | Change Record:                                                                    |
-- | ==============                                                                    |
-- |                                                                                   |
-- | Ver      Date           Author             		Description                    |
-- |========= ============== ================= 			================               |
-- | 0.1      06-Dec-2016    Prashant Shivaji Bhapkar   Initial Version                |
-- +===================================================================================+
  
EXECUTE APPS.AD_ZD_TABLE.UPGRADE ('<Schema>','SHIPMENT_TXN_GT');