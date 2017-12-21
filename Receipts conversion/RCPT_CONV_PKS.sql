CREATE OR REPLACE PACKAGE JCPX_RCV_MRCH_CONV_RCPT_PKG
AS

-- +=================================================================================+
-- | Infosys Development Team                                                        |
-- | Package Name: JCPX_RCV_MRCH_CONV_RCPT_PKG                                       |
-- | Script File Name: JCPX_RCV_MRCH_CONV_RCPT_PKs.sql                                       |
-- | Description: This Package contains the procedures and functions to extract      |
-- |              the receipt information into staging tables and then               |
-- |              validate them and load the data into interface tables              |
-- |                                                                                 |
-- |                                                                                 |
-- | Change Record:                                                                  |
-- | ==============                                                                  |
-- |                                                                                 |
-- | Ver      Date           Author             Description                          |
-- |========= ============== ================= ================                      |
-- | 0.1      26-Dec-2016    Prashant Bhapkar   Initial Version                      |
-- +=================================================================================+

    PROCEDURE jcpx_convert_receipt_main_proc 
                     (
                      xv_errbuf   OUT VARCHAR2,
                      xn_retcode  OUT NUMBER,
                      pv_run_mode IN  VARCHAR2
                     );


    PROCEDURE jcpx_conv_receipt_child_proc 
                      (
                        pv_errbuf   OUT VARCHAR2
                       ,pn_retcode  OUT NUMBER
                       ,pv_run_mode IN  VARCHAR2
                       ,pn_from_header_id IN NUMBER
                       ,pn_to_header_id   IN NUMBER
                      );

    PROCEDURE jcpx_extract_receipt_info ( 
                                         pv_errbuf   OUT VARCHAR2
                                        ,pn_retcode  OUT NUMBER
                                        ,pv_run_mode           IN     VARCHAR2
                                        ,Pv_Po_Header_id_From  IN     VARCHAR2
                                        ,Pv_po_header_id_to    IN     VARCHAR2
                                        ,Pv_delete_flag        IN     VARCHAR2
                                        );


    PROCEDURE jcpx_re_extract_receipt_info(
                                           pv_errbuf   OUT VARCHAR2
                                          ,pn_retcode  OUT NUMBER
                                          ,Pv_Po_Header_id_From  IN     VARCHAR2
                                          ,Pv_po_header_id_to    IN     VARCHAR2
                                         );


    PROCEDURE jcpx_validate_receipt_info (
                                          pv_errbuf   OUT VARCHAR2
                                         ,pn_retcode  OUT NUMBER
                                         ,pv_shpmnt_hdr_from IN NUMBER
                                         ,pv_shpmnt_hdr_to IN NUMBER
                                        );


    PROCEDURE jcpx_process_receipt (
                                    pv_errbuf   OUT VARCHAR2
                                   ,pn_retcode  OUT NUMBER
                                   ,pv_shpmnt_hdr_from IN VARCHAR2
                                   ,pv_shpmnt_hdr_to IN VARCHAR2
                                   );


    PROCEDURE jcpx_submit_std_prg_proc;

    PROCEDURE jcpx_rcv_get_import_errors;

   

    PROCEDURE jcpx_create_audit_entries( pv_run_mode     IN VARCHAR2
                                       ,pv_description  IN VARCHAR2
                                       ,pn_audit_count  IN NUMBER
                                       );
                                       
    PROCEDURE rcv_log_result( pv_errbuf   OUT VARCHAR2
                            ,pn_retcode  OUT NUMBER
                            ,pv_run_mode IN VARCHAR2
                            );
   
                


END JCPX_RCV_MRCH_CONV_RCPT_PKG;
/
SHOW ERRORS