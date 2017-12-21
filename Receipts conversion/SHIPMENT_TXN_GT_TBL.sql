-- +===================================================================================+
-- | Table Name : SHIPMENT_TXN_GT                                             		   |
-- | Script Name: SHIPMENT_TXN_GT_TBL.sql                                     		   |
-- | Description: Used to Store the Receipt Details temporarily for                    |
-- |              Conversion from 11i                                                  |
-- |                                                                                   |
-- | Change Record:                                                                    |
-- | ==============                                                                    |
-- |                                                                                   |
-- | Ver      Date           Author             		Description                    |
-- |========= ============== ================= 			================               |
-- | 0.1      06-Dec-2016    Prashant Shivaji Bhapkar  	Initial Version                |
-- +===================================================================================+

CREATE GLOBAL TEMPORARY TABLE
SHIPMENT_TXN_GT
(LAST_UPDATE_DATE              DATE
,LAST_UPDATED_BY               NUMBER
,USER_NAME                     VARCHAR2(100 )
,START_DATE                    DATE
,END_DATE                      DATE
,VENDOR_ID                     NUMBER
,VENDOR_NUM                    VARCHAR2(30 )
,VENDOR_NAME                   VARCHAR2(240 )
,VENDOR_SITE_ID                NUMBER
,VENDOR_SITE_CODE              VARCHAR2(15 )
,SHIP_TO_LOCATION_ID           NUMBER
,SHIP_TO_LOCATION_CODE         VARCHAR2(60 )
,SHIP_TO_ORGANIZATION_ID       NUMBER
,SHIP_TO_ORGANIZATION_CODE     VARCHAR2(3 )
,ORG_ID                        NUMBER
,OU_NAME                       VARCHAR2(240 )
,PAYMENT_TERMS_ID              NUMBER
,PAYMENT_TERMS                 VARCHAR2(50 )
,EMPLOYEE_ID                   NUMBER(9)
,EMPLOYEE_NUMBER               VARCHAR2(30 )
,EMPLOYEE_NAME                 VARCHAR2(240 )
,SHIPMENT_HEADER_ID            NUMBER
,SHIPMENT_LINE_ID              NUMBER
,TRANSACTION_ID                NUMBER
,TXN_LAST_UPDATE_DATE          DATE
,TXN_LAST_UPDATE_BY            NUMBER
,REQUEST_ID                    NUMBER
,PROGRAM_APPLICATION_ID        NUMBER
,PROGRAM_ID                    NUMBER
,PROGRAM_UPDATE_DATE           DATE
,CATEGORY_ID                   NUMBER
,ITEM_ID                       NUMBER
,TXN_EMPLOYEE_ID               NUMBER(9)
,TXN_VENDOR_ID                 NUMBER
,TXN_VENDOR_SITE_ID            NUMBER
,FROM_ORGANIZATION_ID          NUMBER
,TO_ORGANIZATION_ID            NUMBER
,PO_HEADER_ID                  NUMBER
,PO_NUMBER                     VARCHAR2(20 )
,PO_LINE_ID                    NUMBER
,PO_LINE_NUM                   NUMBER
,PO_LINE_LOCATION_ID           NUMBER
,SHIPMENT_NUM                  NUMBER
,PO_DISTRIBUTION_ID            NUMBER
,PO_DISTRIBUTION_NUM           NUMBER
,DESTINATION_TYPE_CODE         VARCHAR2(25 )
,LOCATION_ID                   NUMBER
,DELIVER_TO_LOCATION_ID        NUMBER
,REASON_ID                     NUMBER
,TRANSACTION_TYPE              VARCHAR2(25 )
,TRANSACTION_DATE              DATE
,ATTRIBUTE5                    VARCHAR2(150 )
,RECEIPT_QUANTITY              NUMBER
,UOM                           VARCHAR2(3 )
,QUANTITY                      NUMBER
,QUANTITY_RECEIVED             NUMBER
,QUANTITY_BILLED               NUMBER
,TXN_QUANTITY                  NUMBER
,SUM_INV_QUANTITY              NUMBER 
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
,HDR_ATTRIBUTE1                VARCHAR2 (150 Byte)
,HDR_ATTRIBUTE2                VARCHAR2 (150 Byte)
,HDR_ATTRIBUTE3                VARCHAR2 (150 Byte)
,HDR_ATTRIBUTE4                VARCHAR2 (150 Byte)
,HDR_ATTRIBUTE5                VARCHAR2 (150 Byte)
,HDR_ATTRIBUTE6                VARCHAR2 (150 Byte)
,HDR_ATTRIBUTE7                VARCHAR2 (150 Byte)
,HDR_ATTRIBUTE8                VARCHAR2 (150 Byte)
,HDR_ATTRIBUTE9                VARCHAR2 (150 Byte)
,HDR_ATTRIBUTE10               VARCHAR2 (150 Byte)
,HDR_ATTRIBUTE11               VARCHAR2 (150 Byte)
,JCPX_PO_MRCH_POCONV_STG_ID     NUMBER
)
ON COMMIT PRESERVE ROWS;

CREATE INDEX SHIPMENT_TXN_GT_N1 
ON SHIPMENT_TXN_GT
  (TRANSACTION_ID);
  
CREATE INDEX SHIPMENT_TXN_GT_N2 
ON SHIPMENT_TXN_GT
  (PO_HEADER_ID,PO_LINE_ID,PO_LINE_LOCATION_ID);

CREATE INDEX SHIPMENT_TXN_GT_N3 
ON SHIPMENT_TXN_GT
  (SHIPMENT_HEADER_ID);  