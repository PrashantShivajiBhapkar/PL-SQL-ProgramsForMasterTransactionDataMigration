-- +===================================================================================+
-- | Table Name : SHIPMENT_LIN_STG                                                     |
-- | Script Name: SHIPMENT_LIN_STG_TBL.sql                                             |
-- | Description: Used to Store the Receipt lines for Conversion from 11i              |
-- |                                                                                   |
-- | Ver      Date           Author             Description                            |
-- |========= ============== ================= ================                        |
-- | 0.1      06-Dec-2016    Prashant Bhapkar        Initial Version                   |
-- +===================================================================================+

CREATE TABLE SHIPMENT_LIN_STG
(SHIPMENT_HEADER_ID             NUMBER
,SHIPMENT_LINE_ID                NUMBER
,TRANSACTION_ID                  NUMBER
,INTERFACE_TRANSACTION_ID        NUMBER
,GROUP_ID                        NUMBER
,LAST_UPDATE_DATE                DATE
,LAST_UPDATED_BY                 NUMBER
,USER_NAME                       VARCHAR2(100 )
,START_DATE                      DATE
,END_DATE                        DATE
,CREATED_BY                      NUMBER
,REQUEST_ID                      NUMBER
,PROGRAM_APPLICATION_ID          NUMBER
,PROGRAM_ID                      NUMBER
,PROGRAM_UPDATE_DATE             DATE
,PROCESSING_STATUS_CODE          VARCHAR2(25 )
,PROCESSING_MODE_CODE           VARCHAR2(25 )
,RECEIPT_SOURCE_CODE             VARCHAR2(25 )
,PROCESSING_REQUEST_ID           NUMBER
,TRANSACTION_STATUS_CODE         VARCHAR2(25 )
,CATEGORY_ID                     NUMBER
,CATEGORY                        VARCHAR2(40 )
,ITEM_ID                         NUMBER
,ITEM                            VARCHAR2(40 )
,ITEM_DESCRIPTION                VARCHAR2 (240 )
,EMPLOYEE_ID                     NUMBER(9)
,EMPLOYEE_NUMBER                 VARCHAR2(30 )
,EMPLOYEE_NAME                   VARCHAR2(240 )
,TXN_VENDOR_ID                   NUMBER
,VENDOR                          VARCHAR2(30 )
,VENDOR_NAME                     VARCHAR2(240 )
,TXN_VENDOR_SITE_ID              NUMBER
,VENDOR_SITE_CODE                VARCHAR2(15 )
,FROM_ORGANIZATION_ID            NUMBER
,FROM_ORGANIZATION_CODE          VARCHAR2(3 )
,TO_ORGANIZATION_ID              NUMBER
,TO_ORGANIZATION_CODE            VARCHAR2(3 )
,PO_HEADER_ID                    NUMBER
,PO_NUMBER                       VARCHAR2(20 )
,PO_LINE_ID                      NUMBER
,PO_LINE_NUM                     NUMBER
,PO_LINE_LOCATION_ID             NUMBER
,SHIPMENT_NUM                    NUMBER
,PO_DISTRIBUTION_ID              NUMBER
,PO_DISTRIBUTION_NUM             NUMBER
,DESTINATION_TYPE_CODE           VARCHAR2(25 )
,LOCATION_ID                     NUMBER
,LOCATION_CODE                   VARCHAR2(60 )
,DELIVER_TO_LOCATION_ID          NUMBER
,DELIVERTO                       VARCHAR2(60 )
,REASON_ID                       NUMBER
,REASON_NAME                     VARCHAR2(30 )
,ORG_ID                          NUMBER
,OU_NAME                         VARCHAR2(240 )
,TRANSACTION_TYPE                VARCHAR2(25 )
,TRANSACTION_DATE                DATE
,RECEIPT_QUANTITY                NUMBER
,UOM                             VARCHAR2(3 )
,ATTRIBUTE5                      VARCHAR2 (150 )
,SOURCE_DOCUMENT_CODE            VARCHAR2(25 )
,HEADER_INTERFACE_ID             NUMBER
,CATEGORY_ID_R12                 NUMBER
,ITEM_ID_R12                     NUMBER
,EMPLOYEE_ID_R12                 NUMBER
,TXN_VENDOR_ID_R12               NUMBER
,TXN_VENDOR_SITE_ID_R12          NUMBER
,FROM_ORGANIZATION_ID_R12        NUMBER
,TO_ORGANIZATION_ID_R12          NUMBER
,PO_HEADER_ID_R12                NUMBER
,PO_LINE_ID_R12                  NUMBER
,PO_LINE_LOCATION_ID_R12         NUMBER
,PO_DISTRIBUTION_ID_R12          NUMBER
,LOCATION_ID_R12                 NUMBER
,DELIVER_TO_LOCATION_ID_R12      NUMBER
,REASON_ID_R12                   NUMBER
,ORG_ID_R12                      NUMBER
,USER_ID_R12                     NUMBER
,UOM_R12                         VARCHAR2(3)
,PROCESS_STATUS                  VARCHAR2(100 )
,ERROR_MESSAGE                   VARCHAR2(1000 )
,PROCESS_STAGE                   VARCHAR2(100 )
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
,ATTRIBUTE1_11I_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE2_11I_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE3_11I_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE4_11I_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE5_11I_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE6_11I_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE7_11I_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE8_11I_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE9_11I_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE10_11I_TXN             VARCHAR2 (150 Byte)
,ATTRIBUTE11_11I_TXN             VARCHAR2 (150 Byte)
,ATTRIBUTE12_11I_TXN             VARCHAR2 (150 Byte)
,ATTRIBUTE13_11I_TXN             VARCHAR2 (150 Byte)
,ATTRIBUTE14_11I_TXN             VARCHAR2 (150 Byte)
,ATTRIBUTE1_R12_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE2_R12_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE3_R12_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE4_R12_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE5_R12_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE6_R12_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE7_R12_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE8_R12_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE9_R12_TXN              VARCHAR2 (150 Byte)
,ATTRIBUTE10_R12_TXN             VARCHAR2 (150 Byte)
,ATTRIBUTE11_R12_TXN             VARCHAR2 (150 Byte)
,ATTRIBUTE12_R12_TXN             VARCHAR2 (150 Byte)
,ATTRIBUTE13_R12_TXN             VARCHAR2 (150 Byte)
,ATTRIBUTE14_R12_TXN             VARCHAR2 (150 Byte)
,JCPX_PO_MRCH_POCONV_STG_ID      NUMBER
,CHARGE_ACCOUNT_ID		 NUMBER 
);

CREATE UNIQUE INDEX SHIPMENT_LIN_STG_U1 
ON SHIPMENT_LIN_STG(INTERFACE_TRANSACTION_ID);

CREATE INDEX SHIPMENT_LIN_STG_N1 
ON SHIPMENT_LIN_STG
  (shipment_line_id, shipment_header_id);
  
CREATE INDEX SHIPMENT_LIN_STG_N2 
ON SHIPMENT_LIN_STG
  (shipment_header_id);
  
CREATE INDEX SHIPMENT_LIN_STG_N3 
ON SHIPMENT_LIN_STG
  (po_header_id);  
  
CREATE INDEX SHIPMENT_LIN_STG_N4
ON SHIPMENT_LIN_STG
  (JCPX_PO_MRCH_POCONV_STG_ID);  