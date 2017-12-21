
-- +===================================================================================+
-- | Table Name : SHIPMENT_HDR_STG     			                                       |
-- | Script Name: SHIPMENT_HDR_STG_TBL.sql      		                               |
-- | Description: Used to Store the Receipt header Details for                         |
-- |              Conversion from 11i                                                  |
-- |                                                                                   |
-- | Ver      Date           Author             		Description                    |
-- |========= ============== ================= 			================               |
-- | 0.1      06-Dec-2016    Prashant Shivaji Bhapkar   Initial Version                |
-- +===================================================================================+


CREATE TABLE SHIPMENT_HDR_STG 
(HEADER_INTERFACE_ID            NUMBER
,GROUP_ID                       NUMBER
,PROCESSING_STATUS_CODE         VARCHAR2(25 )
,RECEIPT_SOURCE_CODE            VARCHAR2(25 )
,TRANSACTION_TYPE               VARCHAR2(25 )
,LAST_UPDATE_DATE               DATE
,LAST_UPDATED_BY                NUMBER
,USER_NAME                      VARCHAR2(100 )
,START_DATE                     DATE
,END_DATE                       DATE
,VENDOR_ID                      NUMBER
,VENDOR_NUM                     VARCHAR2(30 )
,VENDOR_NAME                    VARCHAR2(240 )
,VENDOR_SITE_ID                 NUMBER
,VENDOR_SITE_CODE               VARCHAR2(15 )
,SHIP_TO_LOCATION_ID            NUMBER
,SHIP_TO_LOCATION_CODE          VARCHAR2(60 )
,SHIP_TO_ORGANIZATION_ID        NUMBER(15)
,SHIP_TO_ORGANIZATION_CODE      VARCHAR2(3 )
,ORG_ID                         NUMBER
,OU_NAME                        VARCHAR2(240 )
,PAYMENT_TERMS_ID               NUMBER
,PAYMENT_TERMS                  VARCHAR2(50 )
,EMPLOYEE_ID                    NUMBER
,EMPLOYEE_NUMBER                VARCHAR2(30 )
,EMPLOYEE_NAME                  VARCHAR2(240 )
,SHIPMENT_HEADER_ID             NUMBER
,CREATED_BY                     NUMBER
,VENDOR_ID_R12                  NUMBER
,VENDOR_SITE_ID_R12             NUMBER
,SHIP_TO_LOCATION_ID_R12        NUMBER
,ORG_ID_R12                     NUMBER
,SHIP_TO_ORGANIZATION_ID_R12    NUMBER
,PAYMENT_TERMS_ID_R12           NUMBER
,EMPLOYEE_ID_R12                NUMBER
,PROCESS_STATUS                 VARCHAR2(100 )
,ERROR_MESSAGE                  VARCHAR2(1000 )
,PROCESS_STAGE                  VARCHAR2(100 )
,ATTRIBUTE1_11i                  VARCHAR2 (150 Byte)
,ATTRIBUTE2_11i                  VARCHAR2 (150 Byte)
,ATTRIBUTE3_11i                  VARCHAR2 (150 Byte)
,ATTRIBUTE4_11i                  VARCHAR2 (150 Byte)
,ATTRIBUTE5_11i                  VARCHAR2 (150 Byte)
,ATTRIBUTE6_11i                  VARCHAR2 (150 Byte)
,ATTRIBUTE7_11i                  VARCHAR2 (150 Byte)
,ATTRIBUTE8_11i                  VARCHAR2 (150 Byte)
,ATTRIBUTE9_11i                  VARCHAR2 (150 Byte)
,ATTRIBUTE10_11i                 VARCHAR2 (150 Byte)
,ATTRIBUTE11_11i                 VARCHAR2 (150 Byte)
,ATTRIBUTE1_R12                  VARCHAR2 (150 Byte)
,ATTRIBUTE2_R12                  VARCHAR2 (150 Byte)
,ATTRIBUTE3_R12                  VARCHAR2 (150 Byte)
,ATTRIBUTE4_R12                  VARCHAR2 (150 Byte)
,ATTRIBUTE5_R12                  VARCHAR2 (150 Byte)
,ATTRIBUTE6_R12                  VARCHAR2 (150 Byte)
,ATTRIBUTE7_R12                  VARCHAR2 (150 Byte)
,ATTRIBUTE8_R12                  VARCHAR2 (150 Byte)
,ATTRIBUTE9_R12                  VARCHAR2 (150 Byte)
,ATTRIBUTE10_R12                 VARCHAR2 (150 Byte)
,ATTRIBUTE11_R12                 VARCHAR2 (150 Byte)
,JCPX_PO_MRCH_POCONV_STG_ID      NUMBER
);


CREATE INDEX SHIPMENT_HDR_STG_N1 
ON SHIPMENT_HDR_STG
  (shipment_header_id);
  
CREATE INDEX SHIPMENT_HDR_STG_N2
ON SHIPMENT_HDR_STG
  (JCPX_PO_MRCH_POCONV_STG_ID);


