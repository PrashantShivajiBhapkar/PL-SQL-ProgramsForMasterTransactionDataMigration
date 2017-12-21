CREATE OR REPLACE PACKAGE BODY RCPT_CONV_PKB
AS
   -- +=====================================================================================+=======+
   -- | Package Name: RCPT_CONV_PKB                                       			        		|
   -- | Script File Name: RCPT_CONV_PKB.sql                               	                		|
   -- | Description: This Package contains the procedures and functions to extract      			|
   -- |              the receipt information into staging tables and then               			|
   -- |              validate them and load the data into interface tables              			|
   -- |                                                                                 			|
   -- |                                                                                 			|
   -- | Change Record:                                                                  			|
   -- | ==============                                                                  			|
   -- |                                                                                 			|
   -- | Ver      Date           Author             			Description                          	|
   -- |========= ============== ================= 			================                      	|
   -- | 0.1      26-Dec-2016    Prashant Shivaji Bhapkar   	Initial Version                      	|
   -- | 0.2      10-May-2016    Prashant Shivaji Bhapkar   	Updated correct threading limit for  	|
   -- |                                            			import									|
   -- | 0.3      10-May-2016    Prashant Shivaji Bhapkar   	Updated code to update staging table 	|
   -- | 										   			only for the current thread instead  	|
   -- | 										   			of the entire table to avoid deadlock	|
   -- | 0.4      16-Jun-2016    Prashant Shivaji Bhapkar   	removed rct.attribute5 is null condition |
   -- | 										   			and added code to derive attr11 in R12	|
   -- | 										   			during validation.						|
   -- | 0.5      21-Jun-2016    Prashant Shivaji Bhapkar   	commented code that used to derive values|
   -- | 										   			for attributes beyond attribute9 for     |
   -- | 										   			RCV_SHIPMENT_HEADERS                     |
   -- +==============================================================================================+
   
   ------------------------------- 
   -- Declare Global Variables  --
   -------------------------------
  
   /*cv_language_code            jcpx_glb_errors.language_code%TYPE           := 'US';
   cv_module_name                jcpx_glb_errors.module_code%TYPE             := 'JCPAP';--fnd_global.application_short_name;
   */
   -- Operating Unit
   gn_org_id                     apps.hr_operating_units.organization_id%TYPE ; --:= apps.fnd_profile.VALUE ('ORG_ID');
   -- Application id
   gt_application_id             fnd_application.application_id%TYPE;
   --operating unit
   gv_operating_unit             apps.hr_operating_units.name%TYPE            := NULL;
   gn_set_of_books_id            NUMBER                                       := NULL;
   -- Current user id
   gt_user_id                    fnd_user.user_id%TYPE                        := apps.fnd_profile.VALUE ('USER_ID');
   gc_create_user_id             NUMBER                                       :=0;
   gt_last_updated_by            fnd_user.user_id%TYPE                        := apps.fnd_global.user_id;
   -- Current request id
   gn_request_id                 fnd_concurrent_requests.request_id%TYPE      := apps.fnd_global.conc_request_id;
   -- Program Application Id
   gn_prog_appl_id               NUMBER                                       := fnd_global.prog_appl_id;
   -- Program Id
   gn_program_id                 NUMBER                                       := fnd_global.conc_program_id;
   gn_login_id                   NUMBER                                       := apps.fnd_global.login_id;
   gn_retcode                    NUMBER                                       := 0;
   -- System Date
   gd_creation_date              DATE                                         := SYSDATE;
   -- System Date
   gd_last_update_date           DATE                                         := SYSDATE;
  
   gv_error_msg                  VARCHAR2 (5000);
   gv_line_error_msg             VARCHAR2 (5000);
   gv_line_cnt_error_msg         VARCHAR2 (5000);
   gv_is_validation_flag         VARCHAR2 (1);
   gc_validation_error           VARCHAR2 (100)                               := 'validation error';
   gc_validation_success         VARCHAR2 (100)                               := 'validated';
   gc_load_error                 VARCHAR2 (100)                               := 'load_error';
   gc_load_success               VARCHAR2 (100)                               := 'interfaced';
   gc_new_records                VARCHAR2 (100)                               := 'new';
   gc_import_success             VARCHAR2 (100)                               := 'success';
   gc_import_error               VARCHAR2 (100)                               := 'import error';
   
   gc_process_stage_extract      VARCHAR2 (100)                               := 'Extract';
   gc_process_stage_validation   VARCHAR2 (100)                               := 'Validation';
   gc_process_stage_interfaced   VARCHAR2 (100)                               := 'Interfaced';
   gc_process_stage_load         VARCHAR2 (100)                               := 'Load';
   gn_extract_fail_cnt           NUMBER                                       := 0;
   gv_errbuf                     VARCHAR2(2000)                               := NULL;
   gn_error_retcode              NUMBER                                       := 2;
   gn_warning_retcode            NUMBER                                       := 1;
   gn_success                    NUMBER                                       := 0;
   
   gn_extract_rcv_g_success_cnt  NUMBER                                       := 0;
   gn_extract_rcv_g_fail_cnt     NUMBER                                       := 0;
   
   gn_extract_rcv_h_success_cnt  NUMBER                                       := 0;
   gn_extract_rcv_h_fail_cnt     NUMBER                                       := 0;
   gn_validate_rcv_h_success_cnt NUMBER                                       := 0;
   gn_validate_rcv_h_fail_cnt    NUMBER                                       := 0;
   gn_intf_rcv_h_success_cnt     NUMBER                                       := 0;
   gn_intf_rcv_h_fail_cnt        NUMBER                                       := 0;
   gn_import_rcv_h_success_cnt   NUMBER                                       := 0;
   gn_import_rcv_h_fail_cnt      NUMBER                                       := 0;
   gn_extract_rcv_update_fail_cnt NUMBER 									  := 0;
   
   gn_extract_rcv_l_success_cnt  NUMBER                                       := 0;
   gn_extract_rcv_l_fail_cnt     NUMBER                                       := 0;
   gn_validate_rcv_l_success_cnt NUMBER                                       := 0;
   gn_validate_rcv_l_fail_cnt    NUMBER                                       := 0;
   gn_intf_rcv_l_success_cnt     NUMBER                                       := 0;
   gn_intf_rcv_l_fail_cnt        NUMBER                                       := 0;
   gn_import_rcv_l_success_cnt   NUMBER                                       := 0;
   gn_import_rcv_l_fail_cnt      NUMBER                                       := 0;
   
   gn_rcv_int_sequence               NUMBER;
   gn_extract_rcv_e_h_success_cnt    NUMBER                                       := 0;
   gn_extract_rcv_r_h_success_cnt    NUMBER                                       := 0;
   gn_extract_rcv_r_l_success_cnt    NUMBER                                       := 0;
   gn_extract_rcv_e_l_success_cnt    NUMBER                                       := 0;
   gn_val_rcv_r_h_fail_cnt           NUMBER                                       := 0;
   gn_val_rcv_r_h_success_cnt        NUMBER                                       := 0;
   gn_val_rcv_r_l_success_cnt        NUMBER                                       := 0;
   gn_val_rcv_r_l_fail_cnt           NUMBER                                       := 0;
   gn_pro_rcv_re_h_success_cnt       NUMBER                                       := 0;
   gn_pro_rcv_re_l_success_cnt       NUMBER                                       := 0;
   gn_process_rcv_re_l_fail_cnt      NUMBER                                       := 0;
   gn_process_rcv_re_h_fail_cnt      NUMBER                                       := 0;
   gn_commit_count                   NUMBER           :=0;
 -- +===================================================================================+
 -- | Procedure :  : jcpx_analyze_tables_proc                                           |
 -- | Description: This procedure analyze the Interface and Standard tables before      |
 -- |              calling the Standard Import Programs.                                |
 -- | Parameter Name               Description                                          |
 -- | ==================================================================================|
 -- |  None                         None                                                |
 -- |                                                                                   |
 -- | ==================================================================================|
 -- | Change Record: |                                                                  |
 -- | ============== |                                                                  |
 -- | |                                                                                 |
 -- | Ver      Date           Author             Description                            |
 -- |========= ============== ================= ================                        |
 -- | 0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        |
 -- |                                                                                   |
 -- +===================================================================================+
 PROCEDURE jcpx_analyze_tables_proc 
 IS
  
    lv_error_text                          VARCHAR2(4000);
    l_sql_string                           VARCHAR2(1000)                        := NULL;
    
    
 BEGIN   
    
    BEGIN
       -- Analyze table1
       l_sql_string :='begin APPS.fnd_stats.gather_table_stats(''PO'',''RCV_HEADERS_INTERFACE''); end;';
       
    
       EXECUTE IMMEDIATE l_sql_string;
   
    EXCEPTION
       WHEN OTHERS THEN
    
         lv_error_text :=
              'Others Exception While Analyzing RCV_HEADERS_INTERFACE  Table. ' || SQLERRM;
         
         jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
         --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
     
    END;
    
    BEGIN
       -- Analyze table2
       l_sql_string :='begin APPS.fnd_stats.gather_table_stats(''PO'',''RCV_TRANSACTIONS_INTERFACE''); end;';
       
    
       EXECUTE IMMEDIATE l_sql_string;
   
    EXCEPTION
       WHEN OTHERS THEN
    
         lv_error_text :=
              'Others Exception While Analyzing RCV_TRANSACTIONS_INTERFACE ' || SQLERRM;
         
         jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
         --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
     
    END;

    BEGIN
       -- Analyze table3
       l_sql_string :='begin APPS.fnd_stats.gather_table_stats(''PO'',''RCV_TRANSACTIONS''); end;';
                     
    
       EXECUTE IMMEDIATE l_sql_string;
   
    EXCEPTION
       WHEN OTHERS THEN
    
         lv_error_text :=
              'Others Exception While Analyzing RCV_TRANSACTIONS  Table. ' || SQLERRM;
         
         jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
         --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
     
    END;
    
    BEGIN
       -- Analyze table4
       l_sql_string :='begin APPS.fnd_stats.gather_table_stats(''PO'',''RCV_SHIPMENT_HEADERS''); end;';
                      
    
       EXECUTE IMMEDIATE l_sql_string;
   
    EXCEPTION
       WHEN OTHERS THEN
    
         lv_error_text :=
              'Others Exception While Analyzing RCV_SHIPMENT_HEADERS  Table. ' || SQLERRM;
        
         jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
         --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
     
    END;
    
    BEGIN
       -- Analyze table5
       l_sql_string :='begin APPS.fnd_stats.gather_table_stats(''PO'',''RCV_SHIPMENT_LINES''); end;';
                     
    
       EXECUTE IMMEDIATE l_sql_string;
   
    EXCEPTION
       WHEN OTHERS THEN
    
         lv_error_text :=
              'Others Exception While Analyzing RCV_SHIPMENT_LINES  Table. ' || SQLERRM;
         
         jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
         --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
     
    END;
    
        

 EXCEPTION
    WHEN OTHERS THEN
       lv_error_text :=
                  'Others Exception while analyzing tables in jcpx_analyze_tables_proc ' 
                  || SQLERRM;
       
       jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
       --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);        
 END jcpx_analyze_tables_proc;   
    
    
    -- +===================================================================================+
    -- | Procedure Name: jcpx_convert_receipt_main_proc                                    |
    -- | Description: This is the main procedure which extracts the data from 11i          |
    -- |              instance through db links and picks up all the eligible              |
    -- |              records into staging tables and calls the various                    |
    -- |              package procedures to validate the item.                             |
    -- |              Once all the required validations are done, the data is populated    |
    -- |              into interface tables.                                               |
    -- |                                                                                   |
    -- | Parameters : Type Description                                                     |
    -- |                                                                                   |
    -- | pv_run_mode   IN  Running Mode                                                    |
    -- | x_errbuf      OUT Standard Error buffer                                           |
    -- | x_retcode     OUT Standard Error code                                             |
    -- |                                                                                   |
    -- |                                                                                   |
    -- | Change Record:                                                                    |
    -- | ==============                                                                    |
    -- |                                                                                   |
    -- | Ver      Date           Author             Description                            |
    -- |========= ============== ================= ================                        |
    -- | 0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        |
    -- +===================================================================================+
    
    
    PROCEDURE jcpx_convert_receipt_main_proc 
                     (
                      xv_errbuf   OUT VARCHAR2,
                      xn_retcode  OUT NUMBER,
                      pv_run_mode IN  VARCHAR2
                     )
    IS
         lv_insert_status             VARCHAR2(40)                          := NULL;
         l_sql_string                 VARCHAR2(1000)                        := NULL;
         
         lv_error_text                VARCHAR2(4000)                        := NULL;
         ln_min_header_id             NUMBER                                :=0;
         ln_max_header_id             NUMBER                                :=0;
         ln_receipt_thread_rec_count  NUMBER                                :=0;
         ln_no_of_threads             NUMBER                                :=0;
         ln_from_header_id            NUMBER                                :=0;
         ln_to_header_id              NUMBER                                :=0;
         ln_rcv_main_req_id           NUMBER                                :=0;
         
         TYPE req_rec_type IS RECORD ( req_id   NUMBER) ;                                                                                                                                                                                                                                                        
         TYPE lt_child_req_type IS TABLE OF req_rec_type                                                                                                                                                                                                                                                         
         INDEX BY BINARY_INTEGER ;

         lt_child_req               lt_child_req_type;
         lbol_request_status          BOOLEAN;
         lv_max_wait                  NUMBER := 360000000000;
         lv_phase                     VARCHAR2(2000);
         lv_status                    VARCHAR2(2000);
         lv_dev_phase                 VARCHAR2(2000);
         lv_dev_status                VARCHAR2(2000);
         lv_message                   VARCHAR2(2000);
         ln_intimp_reqid              NUMBER                                := 0;
         lv_error_fatal               VARCHAR2(50);
         ln_req_indx                  NUMBER                                := 0;
         lb_wait                      BOOLEAN                               := FALSE ;
         lv_error_warning             VARCHAR2(50);
         ln_thread_id                 NUMBER           :=0;
         
   
         CURSOR lcsr_process_summary 
         IS
           SELECT rpad(description, 50,' ') process_desc
                 ,lpad(count,10,' ')         process_count
            FROM apps.jcpx_glb_audit
           WHERE request_id =  gn_request_id;
         
    BEGIN
				     
        ------------------------------------------------------------------
        --Calling the procedures for loading
        --validation and insertion
        ------------------------------------------------------------------
        IF UPPER(pv_run_mode) = 'EXTRACT' THEN
           --Delete all the data from Header and lines staging tables.
                   
           -- Truncate Consolidated Temporary staging table
           BEGIN
              -- Truncate the old records from staging table
              l_sql_string :='TRUNCATE TABLE jcpx.SHIPMENT_TXN_GT';
           
              EXECUTE IMMEDIATE l_sql_string;
              
           EXCEPTION 
              WHEN OTHERS THEN
   
                lv_error_text :=
                     'Others Exception While Truncating Consolidated Staging Table. ' || SQLERRM;
                
                jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
                --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
                
                gv_errbuf  := lv_error_text;
                gn_retcode := gn_error_retcode;
              
           END;                   
       
           -- Truncate headers staging table
           BEGIN
              -- Truncate the old records from staging table
              l_sql_string :='TRUNCATE TABLE jcpx.JCPX_RCV_MRCH_SHP_HDR_STG';
           
              EXECUTE IMMEDIATE l_sql_string;
              
           EXCEPTION 
              WHEN OTHERS THEN
   
                lv_error_text :=
                     'Others Exception While Truncating Headers Staging Table. ' || SQLERRM;
               
                jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
                --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
                
                gv_errbuf  := lv_error_text;
                gn_retcode := gn_error_retcode;
              
           END;
          
           -- Truncate lines staging table
           BEGIN
              -- Truncate the old records from staging table
              l_sql_string :='TRUNCATE TABLE SHIPMENT_LIN_STG';
           
              EXECUTE IMMEDIATE l_sql_string;
           EXCEPTION 
              WHEN OTHERS THEN
   
                lv_error_text :=
                     'Others Exception While Truncating Lines Staging Table. ' || SQLERRM;
               
                jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
                --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
                
                gv_errbuf  := lv_error_text;
                gn_retcode := gn_error_retcode;
              
           END;
           

          BEGIN
            SELECT MIN(JCPX_PO_MRCH_POCONV_STG_ID),MAX(JCPX_PO_MRCH_POCONV_STG_ID)
               INTO ln_min_header_id,ln_max_header_id
               FROM JCPX_PO_MRCH_POCONV_LIN_STG;
               
           EXCEPTION
             WHEN OTHERS THEN
                lv_error_text :='Others Exception While getting no of threads '||SQLERRM;
                
                jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
                
                gv_errbuf  := lv_error_text;
                gn_retcode := gn_error_retcode;
           END;
          
        ELSIF UPPER(pv_run_mode) IN ('VALIDATE','PROCESS') THEN
   
           BEGIN
              SELECT MIN(JCPX_PO_MRCH_POCONV_STG_ID),MAX(JCPX_PO_MRCH_POCONV_STG_ID)
              INTO ln_min_header_id,ln_max_header_id
              FROM JCPX_RCV_MRCH_SHP_HDR_STG;
              
           EXCEPTION
               WHEN OTHERS THEN
               
                  lv_error_text :='Others Exception While getting no of threads '||SQLERRM;
                  
                  jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);                  
                  gv_errbuf  := lv_error_text;
                  gn_retcode := gn_error_retcode;
           END;
        END IF;
        

        BEGIN 
           IF  gn_retcode = 0  THEN
           -- getting values from values map for total no of threads
              BEGIN 
                 SELECT vm.value2
                       ,vm.value3
                  INTO ln_no_of_threads
                      ,gn_commit_count -- Version 2.3
                  FROM jcpx_glb_value_map_def vmd 
                      ,jcpx_glb_value_map     vm
                  WHERE vmd.map_code = 'JCPX_MULTI_THREADS'
                    AND vm.value1 = 'JCPX_RCV_CONV_MRCH'
                    AND vmd.map_def_id = vm.map_def_id; 
                 
              EXCEPTION
                WHEN OTHERS THEN
                  lv_error_text :='Others Exception for total no of threads'|| SQLERRM;
              
                  --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
                  jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
                  gv_errbuf  := lv_error_text;
                  gn_retcode := gn_error_retcode;
                 
              END;
               
              --Get the # of headers to be processed for each child request as
             
              ln_receipt_thread_rec_count := ROUND((ln_max_header_id - ln_min_header_id) / ln_no_of_threads);
              
              ln_from_header_id  := ln_min_header_id;
              
              ln_to_header_id    := ln_min_header_id + ln_receipt_thread_rec_count;
              
              jcpx_message_pkg.log_msg('Thread started : ' || lv_status,FALSE,NULL,'LOG'); 
              
              FOR ln_count IN 1 .. ln_no_of_threads
                 LOOP
                 
                 ln_rcv_main_req_id:= 
                 fnd_request.submit_request(
                                      application             => 'JCPAP' 
                                     ,program                 => 'JCPX_AP_MERCH_RCV_CHILD_CONV'
                                     ,description             => NULL
                                     ,start_time              => SYSDATE  
                                     ,Sub_request             => FALSE 
                                     ,argument1               => pv_run_mode   
                                     ,argument2               => ln_from_header_id
                                     ,argument3               => ln_to_header_id
                                            );
                   
                 COMMIT;
                 ------------------------------------------------------------
                 -- If Concurrent Program is submitted successfully, then
                 -- send the concurrent request id value to calling form
                 ------------------------------------------------------------
                 ln_intimp_reqid:= ln_rcv_main_req_id;
                 
                 IF  ln_intimp_reqid  = 0 THEN
                    
                    jcpx_message_pkg.log_msg('Error in Executing JCP Receipt Conversion Program' || SQLERRM);
                    lv_error_fatal:=1; 
                    
                 ELSE
                    
                    lt_child_req(ln_req_indx).req_id   := ln_intimp_reqid;
                    ln_req_indx := ln_req_indx + 1;
                       
                 END IF; 
                 
                 
                 ln_from_header_id  := ln_to_header_id + 1;
                 
                 ln_to_header_id    := ln_from_header_id + ln_receipt_thread_rec_count;
                 
              END LOOP;
              
              
              --wait for all the child request.
              
              IF  lt_child_req.COUNT >0 THEN
                 
                 FOR ln_req_indx IN lt_child_req.FIRST .. lt_child_req.LAST
                    LOOP  
                    
                    
                    ------------------------------------------------------------------------
                    --Wait for the concurrent child requests to complete
                    ------------------------------------------------------------------------
                    
                    
                    lb_wait  := FND_CONCURRENT.WAIT_FOR_REQUEST
                                      (  lt_child_req(ln_req_indx).req_id      
                                       , 30                                         
                                       , 0                                          
                                       , lv_phase                                   
                                       , lv_status                                  
                                       , lv_dev_phase                               
                                       , lv_dev_status                              
                                       , lv_message
                                       );
                                       
                                       
                    -------------------------------------------------------------------------------------- 
                    --Set the status of the request based on the program status of all the child request
                    --------------------------------------------------------------------------------------
                             
                             
                    IF lv_dev_phase  = 'COMPLETE' AND lv_dev_status = 'NORMAL' THEN
                    
                       jcpx_message_pkg.log_msg('JCP Receipt Conversion Program - Child Concurrent Program completed normally. Request ID - '
                                                   ||TO_CHAR(lt_child_req(ln_req_indx).req_id));
                       jcpx_message_pkg.log_msg('JCP Receipt Conversion Program - Child Concurrent Program completed normally '); 
                         
                    ELSIF lv_dev_phase  = 'COMPLETE' AND lv_dev_status = 'WARNING' THEN
                    
                       jcpx_message_pkg.log_msg('JCP Receipt Conversion Program - Child Concurrent Program completed with  warnings. Request ID - '                     
                                                   ||TO_CHAR(lt_child_req(ln_req_indx).req_id));
                       jcpx_message_pkg.log_msg('JCP Receipt Conversion Program - Child Concurrent Program completed with warnings ');
                        
                       gv_errbuf  := lv_error_text;
                       gn_retcode := gn_warning_retcode;  
                         
                    ELSE
                     
                      jcpx_message_pkg.log_msg(' JCP Receipt Conversion Program- Child Concurrent Program completed with  status.'
                                                 ||lv_dev_status
                                                 ||' Request ID - '||TO_CHAR(lt_child_req(ln_req_indx).req_id));
                      jcpx_message_pkg.log_msg('JCP Receipt Conversion Program- Child Concurrent Program completed with with  status.'
                                                 ||lv_dev_status);
                      gv_errbuf  := lv_error_text;
                      gn_retcode := gn_error_retcode;
                        
                    END IF; 
                     
                 END LOOP;
                 
              ELSE
              
                 jcpx_message_pkg.log_msg(' JCP Receipt Conversion Program - Child Concurrent Program Not submitted');
                 jcpx_message_pkg.log_msg(' JCP Receipt Conversion Program- Child Concurrent Program Not submitted');
                 lv_error_warning:=1;
                 
              END IF;

           ELSE   
              lv_error_text :='Truncation of tables gave errors '||SQLERRM;
              
              --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
              jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
              gv_errbuf  := lv_error_text;
              gn_retcode := gn_error_retcode;
              
              
           END IF;
           
     
        IF pv_run_mode = 'PROCESS' THEN
        
         jcpx_message_pkg.log_msg('Starting processing ',FALSE,NULL,'LOG');
           
          -- jcpx_submit_std_request;
           
        END IF;
     
       
        EXCEPTION
       
          WHEN OTHERS THEN
          
             lv_error_text :='Others Exception While getting total no of threads for concurrent program'
                             ||SQLERRM;
             --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
             jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
             
             gv_errbuf  := lv_error_text;
             gn_retcode := gn_error_retcode;
        END;

    
       COMMIT;
       
    -----------------
    --Version 1.5
    -----------------
    -- Getting the Validation Counts 
    IF UPPER (pv_run_mode) = 'VALIDATE'
    THEN
       BEGIN
            SELECT COUNT(1)
              INTO gn_validate_rcv_h_success_cnt 
              FROM JCPX_RCV_MRCH_SHP_HDR_STG
             WHERE process_status = gc_validation_success;   
       
             SELECT COUNT(1)
    	      INTO gn_validate_rcv_h_fail_cnt 
    	      FROM JCPX_RCV_MRCH_SHP_HDR_STG
             WHERE process_status = gc_validation_error;
             
       EXCEPTION
       WHEN OTHERS THEN
               lv_error_text :='Others Error while deriving validation counts for Headers table'||SQLERRM;
               jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
       END;
     
       BEGIN
            SELECT COUNT(1)
              INTO gn_validate_rcv_l_success_cnt 
              FROM SHIPMENT_LIN_STG
             WHERE process_status = gc_validation_success;   
       
             SELECT COUNT(1)
    	      INTO gn_validate_rcv_l_fail_cnt 
    	      FROM SHIPMENT_LIN_STG
             WHERE process_status = gc_validation_error;
             
       EXCEPTION
       WHEN OTHERS THEN
               lv_error_text :='Others Error while deriving validation counts for Lines table'||SQLERRM;
               jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
       END;         
       rcv_log_result( gv_errbuf
                       ,gn_retcode
                       ,pv_run_mode);
       
     END IF;       
           /*Call of the procedures have been moved to main to avoid multiple submission
           *********************************************************************************************/
                 
        IF UPPER (pv_run_mode) = 'PROCESS'
        THEN         
                 
           jcpx_analyze_tables_proc;
        
        ------------------------------------------------------------------------------------------------
        -- Calling jcpx_submit_std_prg_proc to submit standard Receiving Open Interface (ROI) Program --
        ------------------------------------------------------------------------------------------------
           jcpx_submit_std_prg_proc;
           
           
        ---------------------------------------------------------------------------------
        -- Calling jcpx_rcv_get_import_errors to update import errors in staging table --
        ---------------------------------------------------------------------------------
           
           jcpx_rcv_get_import_errors;
           
        
        END IF;
       xv_errbuf  := gv_errbuf;
       xn_retcode := gn_retcode;   
       
   
    EXCEPTION
       WHEN OTHERS THEN
    
          lv_error_text := 'Unexpected Error while converting the Receipts. ' || SQLERRM;
      
         
          jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
          --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);   
       
    END jcpx_convert_receipt_main_proc;
    
    -- +===================================================================================+
    -- | Procedure Name: jcpx_conv_receipt_child_proc                                      |
    -- | Description: This is the child program which is called from the main program      |
    -- |              and runs for the various runmodes for a particular number of         |
    -- |              headers id.All the four modes are called in the child record.        |
    -- |                                                                                   |
    -- | Parameters : Type Description                                                     |
    -- |                                                                                   |
    -- | pv_run_mode        IN   Running Mode                                              |
    -- | po_from_header_id  IN   from header id                                            |
    -- | po_to_header_id    IN   to header id                                              |
    -- | x_errbuf      OUT Standard Error buffer                                           |
    -- | x_retcode     OUT Standard Error code                                             |
    -- |                                                                                   |
    -- |                                                                                   |
    -- | Change Record:                                                                    |
    -- | ==============                                                                    |
    -- |                                                                                   |
    -- | Ver      Date           Author             Description                            |
    -- |========= ============== ================= ================                        |
    -- | 0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        |
    -- +===================================================================================+
    
    PROCEDURE jcpx_conv_receipt_child_proc 
                      (
                        pv_errbuf   OUT VARCHAR2
                       ,pn_retcode  OUT NUMBER
                       ,pv_run_mode IN  VARCHAR2
                       ,pn_from_header_id IN NUMBER
                       ,pn_to_header_id   IN NUMBER
                      )
    IS
       l_sql_string        VARCHAR2(1000)                        := NULL;
    
       lv_error_text                VARCHAR2(4000)                        := NULL;
 BEGIN
    
    BEGIN
       SELECT vm.value3
         INTO gn_commit_count 
         FROM jcpx_glb_value_map_def vmd 
             ,jcpx_glb_value_map     vm
        WHERE vmd.map_code = 'JCPX_MULTI_THREADS'
          AND vm.value1 = 'JCPX_RCV_CONV_MRCH'
          AND vmd.map_def_id = vm.map_def_id;
 
    EXCEPTION
    WHEN OTHERS
    THEN
        jcpx_message_pkg.log_msg('Error:: Error deriving commit count from value map');
    
    END;
    
       BEGIN
         
            SELECT user_id
              INTO gc_create_user_id
              FROM fnd_user
            WHERE user_name = 'JCPCONV2'
              AND  NVL(start_date,sysdate) <= sysdate
              AND  NVL(end_date,sysdate) >= sysdate;
             
        EXCEPTION 
           WHEN NO_DATA_FOUND THEN
              gc_create_user_id := fnd_global.user_id;
              lv_error_text :=
                     'User JCPCONV2 is not present. ' || SQLERRM;
             
              jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
              --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
         
           WHEN OTHERS THEN    
              lv_error_text :=
                     'Others Exception While Deriving User ID for JCPCONV2 user. ' || SQLERRM;
             
              jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
              --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
              
        END;
     
	   --Deriving organization id. 
	   BEGIN
         SELECT organization_id
           INTO gn_org_id
           FROM hr_operating_units
          WHERE name = 'JCP Domestic Merchandise'
            AND NVL(date_from,SYSDATE)<= SYSDATE
            AND NVL(date_to,SYSDATE) >=SYSDATE;
       EXCEPTION
           WHEN OTHERS THEN
                lv_error_text :='Others Error for Operating Unit Validation '|| SQLERRM;
                jcpx_message_pkg.log_msg(p_msg_text => lv_error_text); 
                gv_errbuf  := lv_error_text;
                gn_retcode := gn_error_retcode;
       END; 
	 
       --Deriving gv_operating_unit and gn_set_of_books_id.  
        BEGIN
           SELECT  name
                  ,set_of_books_id
             INTO  gv_operating_unit
                  ,gn_set_of_books_id
              FROM hr_operating_units
               WHERE organization_id = gn_org_id
                 AND NVL(date_from,SYSDATE)<= SYSDATE
                 AND NVL(date_to,SYSDATE) >=SYSDATE;
        EXCEPTION
            WHEN OTHERS THEN
               lv_error_text :='Others Error for Org ID Validation '|| SQLERRM;
               jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
       
        END;
       
    
       IF UPPER (pv_run_mode) = 'EXTRACT'
       THEN
          
          
          --Call jcpx_extract_receipt_info
   
           jcpx_extract_receipt_info( gv_errbuf
                                     ,gn_retcode
                                     ,pv_run_mode           => 'EXTRACT'
                                     ,Pv_Po_Header_id_From  => pn_from_header_id
                                     ,Pv_po_header_id_to    => pn_to_header_id
                                     ,Pv_delete_flag        => 'Y'
                                     );
          
         --Getting log
         rcv_log_result( gv_errbuf
                        ,gn_retcode
                        ,pv_run_mode);
          
          
       ELSIF UPPER (pv_run_mode) = 'VALIDATE'
       THEN
          --Call jcpx_validate_receipt_info;
          
          jcpx_validate_receipt_info
                           ( gv_errbuf
                            ,gn_retcode
                            ,pv_shpmnt_hdr_from  => pn_from_header_id
                            ,pv_shpmnt_hdr_to    => pn_to_header_id
                           );
		 --Getting log
         rcv_log_result( gv_errbuf
                        ,gn_retcode
                        ,pv_run_mode);
          
        
       
       ELSIF UPPER (pv_run_mode) = 'PROCESS'
       THEN
      
       
          --Call jcpx_process_receipt
          
          jcpx_process_receipt
                             ( gv_errbuf
                              ,gn_retcode
                              ,pv_shpmnt_hdr_from  => pn_from_header_id
                              ,pv_shpmnt_hdr_to    => pn_to_header_id
                           );
          
         --Getting log
         rcv_log_result( gv_errbuf
                        ,gn_retcode
                        ,pv_run_mode);
       
       ELSIF UPPER (pv_run_mode) = 'RE-EXTRACT'
       THEN
          
          --Call jcpx_re_extract_receipt_info;
             jcpx_re_extract_receipt_info( gv_errbuf
                                          ,gn_retcode
                                          ,Pv_Po_Header_id_From  => pn_from_header_id
                                          ,Pv_po_header_id_to    => pn_to_header_id
                                           );
          -------------------------------------
          --  Deleting re-extracted records  --
          -------------------------------------
             
           -- delete from header staging table
           BEGIN
              DELETE FROM JCPX_RCV_MRCH_SHP_HDR_STG rsh
                 WHERE UPPER(rsh.process_status) = 'RE-PROCESS'
                    OR EXISTS (
                                SELECT 1
                                  FROM SHIPMENT_LIN_STG rsl
                                 WHERE rsh.shipment_header_id = rsl.shipment_header_id
                                   AND UPPER(rsl.process_status) = 'RE-PROCESS'
                              );
           
           EXCEPTION 
              WHEN OTHERS THEN
   
                lv_error_text :=
                     'Others Exception While delete from header Staging Table. ' || SQLERRM;
               
                jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
                --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
                
                gv_errbuf  := lv_error_text;
                gn_retcode := gn_error_retcode;
              
           END;
           
           -- delete from lines staging table
           BEGIN
              DELETE FROM SHIPMENT_LIN_STG rsl
                 WHERE UPPER(rsl.process_status) = 'RE-PROCESS'
                    OR EXISTS (
                                SELECT 1
                                  FROM JCPX_RCV_MRCH_SHP_HDR_STG rsh
                                 WHERE rsh.shipment_header_id = rsl.shipment_header_id
                                   AND UPPER(rsh.process_status) = 'RE-PROCESS'
                              );
                            
                 
           
           EXCEPTION 
              WHEN OTHERS THEN
   
                lv_error_text :=
                     'Others Exception While delete from lines Staging Table. ' || SQLERRM;
               
                jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
                --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
                
                gv_errbuf  := lv_error_text;
                gn_retcode := gn_error_retcode;
              
           END;

          
          
         --Getting log
         rcv_log_result( gv_errbuf
                        ,gn_retcode
                        ,pv_run_mode);
       END IF;
    
    EXCEPTION
       WHEN OTHERS THEN
       
          lv_error_text := 'Unexpected Error while converting the Receipts. ' || SQLERRM;
          
          
          jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
          --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);   
    
          pv_errbuf  := lv_error_text;
          pn_retcode := gn_error_retcode;
    
    END jcpx_conv_receipt_child_proc;
    
   -- +===================================================================================+
   -- | Procedure Name: jcpx_extract_receipt_info                                         |
   -- | Description: This is the procedure which extracts the data from 11i               |
   -- |              instance through db links and do the bulk collect of                 |
   -- |              all the eligible records into staging tables.                        |
   -- |                                                                                   |
   -- | Parameters : Type Description                                                     |
   -- |                                                                                   |
   -- | pv_run_mode        IN   Running Mode                                              |
   -- | po_from_header_id  IN   from header id                                            |
   -- | po_to_header_id    IN   to header id                                              |
   -- | Pv_delete_flag     IN   delete flag                                               |
   -- | x_errbuf           OUT  Standard Error buffer                                     |
   -- | x_retcode          OUT  Standard Error code                                       |
   -- |                                                                                   |
   -- |                                                                                   |
   -- | Change Record:                                                                    |
   -- | ==============                                                                    |
   -- |                                                                                   |
   -- | Ver      Date           Author             Description                            |
   -- |========= ============== ================= ================                        |
   -- | 0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        |
   -- +===================================================================================+
   
   PROCEDURE jcpx_extract_receipt_info ( 
                                         pv_errbuf   OUT VARCHAR2
                                        ,pn_retcode  OUT NUMBER
                                        ,pv_run_mode           IN     VARCHAR2
                                        ,Pv_Po_Header_id_From  IN     VARCHAR2
                                        ,Pv_po_header_id_to    IN     VARCHAR2
                                        ,Pv_delete_flag        IN     VARCHAR2
                                        )
   IS
     
      lv_error_text                 VARCHAR2(4000)                        := NULL;
      lv_error_msg                  VARCHAR2 (4000)                := NULL;
      
      TYPE t_jcpx_rcv_shipment_hdrs_tab IS TABLE OF   SHIPMENT_TXN_GT%ROWTYPE INDEX BY BINARY_INTEGER;
      gt_jcpx_rcv_shipment_hdrs_tab      t_jcpx_rcv_shipment_hdrs_tab;
      
      TYPE t_jcpx_rcv_shpmnt_lines_tab IS TABLE OF SHIPMENT_LIN_STG%ROWTYPE INDEX BY BINARY_INTEGER;
      gtab_jcpx_rcv_shpmnt_lns_tab      t_jcpx_rcv_shpmnt_lines_tab;
      
      
      TYPE t_jcpx_rcv_shpmnt_hdrs_tab IS TABLE OF JCPX_RCV_MRCH_SHP_HDR_STG%ROWTYPE INDEX BY BINARY_INTEGER;
      gtab_jcpx_rcv_shpmnt_hdrs_tab      t_jcpx_rcv_shpmnt_hdrs_tab;
	  
	       
      ln_rec_count                       NUMBER;
      ln_jcpx_receipts_err_count         NUMBER                    := 0;
      
      CURSOR csr_rcv_gtemp
      IS
          SELECT rsh.last_update_date
                ,rsh.last_updated_by
                ,NULL --fu.user_name
                ,NULL --fu.start_date
                ,NULL --fu.end_date
                ,rsh.vendor_id
                ,pv.segment1 as vendor_num
                ,pv.vendor_name      
                ,rsh.vendor_site_id
				,NULL as VENDOR_SITE_CODE				
                ,rsl.ship_to_location_id      
                ,hl.location_code as ship_to_location_code
                ,hl.inventory_organization_id as ship_to_organization_id
                ,NULL as ship_to_organization_code
                ,gn_org_id as org_id
                ,NULL -- ou_name
                ,rsh.payment_terms_id
                ,(SELECT terms.name 
                    FROM apps.AP_TERMS_11I terms
                   WHERE terms.term_id = rsh.payment_terms_id) as payment_terms
                ,rsh.employee_id 
                ,ppf.employee_number
                ,ppf.full_name as employee_name
                ,rsh.shipment_header_id
                ,rsl.shipment_line_id
                ,rct.transaction_id
                ,NULL --rct.last_update_date as txn_last_update_date
                ,NULL --rct.last_updated_by as txn_last_update_by
                ,NULL --rct.request_id
                ,NULL --rct.program_application_id
                ,NULL --rct.program_id
                ,NULL --rct.program_update_date
                ,rsl.category_id
                ,rsl.item_id
                ,rct.employee_id as txn_employee_id
                ,rct.vendor_id as txn_vendor_id
                ,rct.vendor_site_id as txn_vendor_site_id
                ,rsl.from_organization_id
                ,rsl.to_organization_id
                ,rct.po_header_id
                ,pll.po_number
                ,rct.po_line_id
                ,pll.line_num as po_line_num
                ,rct.po_line_location_id
                ,pll.shipment_num
                ,rct.po_distribution_id
                ,(
                   SELECT distribution_num
                     FROM  PO_MRCH_DISTR_ALL_11I pd
                    WHERE pd.line_location_id = pll.line_location_id_11I
                      AND pd.po_line_id = pll.po_line_id_11I
                      AND pd.po_header_id = pll.po_header_id_11I
                 ) as po_distribution_num
                ,rct.destination_type_code
                ,rct.location_id
                ,rct.deliver_to_location_id
                ,rct.reason_id
                ,rct.transaction_type
                ,rct.transaction_date
                ,rct.attribute5
                ,(CASE 
		    WHEN ( NVL(pll.quantity_received,0) - NVL(pll.quantity_billed,0) ) <= 0
		      THEN pll.quantity_received
		    ELSE 
		      NVL(pll.quantity_received,0) - NVL(pll.quantity_billed,0)
		  END
                 ) as receipt_quantity                 
                 ------------------------------------------------------------
                ,pll.uom_code as uom
                ,pll.quantity
                ,pll.quantity_received
                ,pll.quantity_billed
                ,rct.quantity as txn_quantity
                ,pll.sum_inv_quantity
                ,rct.attribute1
				,rct.attribute2
                ,rct.attribute3
                ,rct.attribute4
				,rct.attribute5
                ,rct.attribute6
                ,rct.attribute7
                ,rct.attribute8
				,rct.attribute9
                ,rct.attribute10
                ,rct.attribute11
                ,rct.attribute12
                ,rct.attribute13
                ,rct.attribute14
				,pll.line_attribute1_r12
				,pll.line_attribute2_r12
				,NULL
				,NULL
				,pll.line_attribute5_r12
				,pll.line_attribute6_r12
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
                ,rsh.attribute1  hdr_attribute1
                ,rsh.attribute2  hdr_attribute2
                ,rsh.attribute3  hdr_attribute3
                ,rsh.attribute4  hdr_attribute4
                ,rsh.attribute5  hdr_attribute5
                ,rsh.attribute6  hdr_attribute6
                ,rsh.attribute7  hdr_attribute7
                ,rsh.attribute8  hdr_attribute8
                ,rsh.attribute9  hdr_attribute9
                ,rsh.attribute10 hdr_attribute10
                ,rsh.attribute11 hdr_attribute11
                ,pll.JCPX_PO_MRCH_POCONV_STG_ID 
           FROM   JCPX_PO_MRCH_POCONV_LIN_STG pll
                 ,apps.RCV_TRANSACTIONS_11I rct     -- Version 3.1
                 ,apps.RCV_SHIPMENT_HEADERS_11I rsh -- Version 3.1 
                 ,apps.RCV_SHIPMENT_LINES_11I rsl   -- Version 3.1
                 ,apps.PO_MRCH_VENDORS_11I pv
                 ,apps.PO_MRCH_VENDOR_SITES_11I pvs      
                 ,apps.HR_LOCATIONS_ALL_11I hl   
                 ,apps.PER_ALL_PEOPLE_F_11I ppf   
				 ,apps.PO_MRCH_HEADERS_ALL_11I poh
           WHERE pll.line_location_id_11I = rct.po_line_location_id
             AND pll.po_header_id_11I = rct.po_header_id      
             AND pll.po_line_id_11I = rct.po_line_id
             AND rct.shipment_header_id = rsh.shipment_header_id
             AND rct.shipment_line_id = rsl.shipment_line_id
             AND rsh.shipment_header_id = rsl.shipment_header_id
             AND rct.transaction_type = 'RECEIVE'
             --AND rct.attribute5 IS NULL  commented for version 0.4
             AND ABS(ROUND((NVL(pll.quantity_received,0) -  NVL(pll.quantity_billed,0)),1)) <> 0
             AND pll.cancel_flag = 'N'
             AND rsh.vendor_id = pv.vendor_id
             AND rsh.vendor_site_id = pvs.vendor_site_id
             AND rsl.ship_to_location_id = hl.location_id
             AND rsh.employee_id = ppf.person_id(+)
             AND NVL(ppf.person_type_id,6) <> 9
             AND rsh.attribute9 IS NOT NULL
			 AND poh.PO_HEADER_ID = pll.PO_HEADER_ID_11I
			 AND poh.SEGMENT1 LIKE rsh.ATTRIBUTE9||'%'
			 AND pll.QUANTITY_RECEIVED <> 0
			 AND pll.PROCESS_STATUS = 'SUCCESS'
             AND pll.JCPX_PO_MRCH_POCONV_STG_ID BETWEEN pv_po_header_id_from AND Pv_po_header_id_to
			 ;
 
      CURSOR csr_rcv_lines
      IS
          SELECT rct.shipment_header_id
                ,rct.shipment_line_id
                ,rct.transaction_id
                ,NULL
                ,NULL
                ,rct.last_update_date
                ,rct.last_updated_by
                ,NULL --fu.user_name
                ,NULL --fu.start_date
                ,NULL --fu.end_date
                ,NULL
                ,rct.request_id
                ,rct.program_application_id
                ,rct.program_id
                ,rct.program_update_date
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,rct.category_id
                ,mc.segment1 as category
                ,rct.item_id
                ,NULL
                ,NULL
                ,rct.employee_id
                ,ppf.employee_number
                ,ppf.full_name as employee_name
                ,rct.txn_vendor_id
                ,pv.segment1 as vendor
                ,pv.vendor_name
				,NULL AS VENDOR_SITE_ID_R12
				,phs.VENDOR_SITE_CODE
                ,rct.from_organization_id
                ,NULL as from_organization_code
                ,rct.to_organization_id
                ,NULL as to_organization_code
                ,rct.po_header_id
                ,rct.po_number
                ,rct.po_line_id
                ,rct.po_line_num
                ,rct.po_line_location_id
                ,rct.shipment_num
                ,rct.po_distribution_id
                ,rct.po_distribution_num
                ,rct.destination_type_code
                ,rct.location_id
                ,hl.location_code
                ,rct.deliver_to_location_id
                ,hl1.location_code deliverto
                ,rct.reason_id
                ,mr.reason_name
                ,gn_org_id as org_id
                ,NULL -- ou_name
                ,transaction_type
                ,transaction_date
                ,receipt_quantity
                ,uom
                ,rct.attribute5
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,'new'
                ,NULL
                ,'Extract'
                ,rsl.ATTRIBUTE1
                ,rsl.ATTRIBUTE2
                ,rsl.ATTRIBUTE3
                ,rsl.ATTRIBUTE4
                ,rsl.ATTRIBUTE5
                ,rsl.ATTRIBUTE6
                ,rsl.ATTRIBUTE7
                ,rsl.ATTRIBUTE8
                ,rsl.ATTRIBUTE9
                ,rsl.ATTRIBUTE10
                ,rsl.ATTRIBUTE11
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,rct.ATTRIBUTE1_11I_TXN
				,rct.ATTRIBUTE2_11I_TXN
				,rct.ATTRIBUTE3_11I_TXN
				,rct.ATTRIBUTE4_11I_TXN
				,rct.ATTRIBUTE5_11I_TXN
				,rct.ATTRIBUTE6_11I_TXN
				,rct.ATTRIBUTE7_11I_TXN
				,rct.ATTRIBUTE8_11I_TXN
				,rct.ATTRIBUTE9_11I_TXN
				,rct.ATTRIBUTE10_11I_TXN
				,rct.ATTRIBUTE11_11I_TXN
				,rct.ATTRIBUTE12_11I_TXN
				,rct.ATTRIBUTE13_11I_TXN
				,rct.ATTRIBUTE14_11I_TXN
				,rct.ATTRIBUTE1_R12_TXN
				,rct.ATTRIBUTE2_R12_TXN
				,rct.ATTRIBUTE3_R12_TXN
				,rct.ATTRIBUTE4_R12_TXN
				,rct.ATTRIBUTE5_R12_TXN
				,rct.ATTRIBUTE6_R12_TXN
				,rct.ATTRIBUTE7_R12_TXN
				,rct.ATTRIBUTE8_R12_TXN
				,rct.ATTRIBUTE9_R12_TXN
				,rct.ATTRIBUTE10_R12_TXN
				,rct.ATTRIBUTE11_R12_TXN
				,rct.ATTRIBUTE12_R12_TXN
				,rct.ATTRIBUTE13_R12_TXN
				,rct.ATTRIBUTE14_R12_TXN
				,rct.JCPX_PO_MRCH_POCONV_STG_ID 
          FROM  SHIPMENT_TXN_GT rct
				 ,apps.RCV_SHIPMENT_LINES_11I rsl
                 ,apps.AP_TERMS_11I terms
                 ,apps.PER_ALL_PEOPLE_F_11I ppf
                 ,apps.MTL_CATEGORIES_B_11I mc
                 ,apps.PO_MRCH_VENDORS_11I pv
                 ,apps.PO_MRCH_VENDOR_SITES_11I pvs
                 ,apps.HR_LOCATIONS_ALL_11I hl
                 ,apps.HR_LOCATIONS_ALL_11I hl1
                 ,apps.MTL_TRANSACTION_REASONS_11I mr
				 ,JCPX_PO_MRCH_POCONV_HDR_STG phs
           WHERE rct.SHIPMENT_HEADER_ID = rsl.SHIPMENT_HEADER_ID
		     AND rct.SHIPMENT_LINE_ID = rsl.SHIPMENT_LINE_ID
		     AND rct.txn_vendor_id = pv.vendor_id
             AND rct.txn_vendor_site_id = pvs.vendor_site_id
             AND rct.transaction_id = (
                                          SELECT MAX(transaction_id)
                                            FROM SHIPMENT_TXN_GT rct1
                                           WHERE rct.po_header_id =rct1.po_header_id
                                             AND rct.po_line_id= rct1.po_line_id
                                             AND rct.po_line_location_id = rct1.po_line_location_id
                                        )
             AND rct.location_id = hl.location_id(+)
             AND rct.payment_terms_id = terms.term_id(+)
             AND rct.category_id = mc.category_id (+)
             AND rct.txn_employee_id = ppf.person_id(+)
             AND NVL(ppf.person_type_id,6) <> 9
             AND rct.deliver_to_location_id = hl1.location_id (+)
             AND rct.reason_id = mr.reason_id (+)
			 AND phs.JCPX_PO_MRCH_POCONV_STG_ID = rct.JCPX_PO_MRCH_POCONV_STG_ID
             AND NOT EXISTS 
                        ( SELECT 1
                            FROM SHIPMENT_LIN_STG rsl
                           WHERE rsl.transaction_id = rct.transaction_id
                        );
                 
      
      CURSOR csr_rcv_headers
      IS
          SELECT DISTINCT
                 NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,rsh.last_update_date
                ,rsh.last_updated_by
                ,rsh.user_name
                ,rsh.start_date
                ,rsh.end_date
                ,rsh.vendor_id
                ,rsh.vendor_num
                ,rsh.vendor_name
                ,rsh.vendor_site_id
                ,rsl.vendor_site_code
                ,rsh.ship_to_location_id
                ,rsh.ship_to_location_code
                ,rsh.ship_to_organization_id
                ,rsh.ship_to_organization_code
                ,rsh.org_id
                ,rsh.ou_name
                ,rsh.payment_terms_id
                ,rsh.payment_terms
                ,rsh.employee_id
                ,rsh.employee_number
                ,rsh.employee_name
                ,rsh.shipment_header_id
                ,NULL
                ,NULL
                ,rsl.txn_vendor_site_id
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,'new'
                ,NULL
                ,'Extract'
                ,rsh.HDR_ATTRIBUTE1
                ,rsh.HDR_ATTRIBUTE2
                ,rsh.HDR_ATTRIBUTE3
                ,rsh.HDR_ATTRIBUTE4
                ,rsh.HDR_ATTRIBUTE5
                ,rsh.HDR_ATTRIBUTE6
                ,rsh.HDR_ATTRIBUTE7
                ,rsh.HDR_ATTRIBUTE8
                ,rsh.HDR_ATTRIBUTE9
                ,rsh.HDR_ATTRIBUTE10
                ,rsh.HDR_ATTRIBUTE11
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
                ,rsh.JCPX_PO_MRCH_POCONV_STG_ID 
          FROM  SHIPMENT_TXN_GT rsh
              , SHIPMENT_LIN_STG rsl
          WHERE rsh.shipment_header_id = rsl.shipment_header_id
            AND NOT EXISTS 
                        ( SELECT 1
                            FROM JCPX_RCV_MRCH_SHP_HDR_STG rsh1
                           WHERE rsh1.shipment_header_id = rsh.shipment_header_id
                        );     
           
      
   BEGIN
     
      -------------------------------------------------------------------------
      -- Extracting Shipment information for eligible PO Lines
      -------------------------------------------------------------------------
      OPEN csr_rcv_gtemp;
      
      LOOP
         FETCH csr_rcv_gtemp
         BULK COLLECT INTO gt_jcpx_rcv_shipment_hdrs_tab LIMIT gn_commit_count;
      
         BEGIN
             FORALL ln_rec_count IN gt_jcpx_rcv_shipment_hdrs_tab.FIRST .. gt_jcpx_rcv_shipment_hdrs_tab.LAST
                INSERT INTO SHIPMENT_TXN_GT
                     VALUES gt_jcpx_rcv_shipment_hdrs_tab (ln_rec_count);
                     
                gn_extract_rcv_g_success_cnt := gn_extract_rcv_g_success_cnt + SQL%ROWCOUNT;
                
                COMMIT;
                 
         EXCEPTION
            WHEN OTHERS THEN
           
              -- Any Exception, ROLLBACK the data
               ROLLBACK;
               
               ln_jcpx_receipts_err_count := SQL%BULK_EXCEPTIONS.COUNT;
               gn_extract_rcv_g_fail_cnt  := gn_extract_rcv_g_fail_cnt+ln_jcpx_receipts_err_count;
     
               lv_error_text := 'Error while Bulk Insert into Global temporary Staging Table. Error Message:';
    
               FOR i IN 1 .. ln_jcpx_receipts_err_count
               LOOP
               
                  lv_error_msg  := SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE);
                  lv_error_text := lv_error_text||lv_error_msg;
    
                  
               END LOOP;
              
               jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
               --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
               
         END;
         
         
         EXIT WHEN (csr_rcv_gtemp%NOTFOUND);
      END LOOP;
      CLOSE csr_rcv_gtemp;
     
      -------------------------------------------------------------------------
      -- Extracting Latest Shipment if Multiple shipments
      -------------------------------------------------------------------------
    OPEN csr_rcv_lines;
    
    LOOP
       FETCH csr_rcv_lines
       BULK COLLECT INTO gtab_jcpx_rcv_shpmnt_lns_tab LIMIT gn_commit_count;
    
       BEGIN
           FORALL ln_rec_count IN gtab_jcpx_rcv_shpmnt_lns_tab.FIRST .. gtab_jcpx_rcv_shpmnt_lns_tab.LAST
              INSERT INTO SHIPMENT_LIN_STG
                   VALUES gtab_jcpx_rcv_shpmnt_lns_tab (ln_rec_count);
                   
              gn_extract_rcv_l_success_cnt := gn_extract_rcv_l_success_cnt + SQL%ROWCOUNT;
              
              COMMIT;
               
       EXCEPTION
          WHEN OTHERS THEN
         
            -- Any Exception, ROLLBACK the data
             ROLLBACK;
             
             ln_jcpx_receipts_err_count := SQL%BULK_EXCEPTIONS.COUNT;
             gn_extract_rcv_l_fail_cnt  := gn_extract_rcv_l_fail_cnt+ln_jcpx_receipts_err_count;
   
             lv_error_text := 'Error while Bulk Insert into Lines Staging Table. Error Message:';
  
             FOR i IN 1 .. ln_jcpx_receipts_err_count
             LOOP
             
                lv_error_msg  := SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE);
                lv_error_text := lv_error_text||lv_error_msg;
  
                
             END LOOP;
            
             jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
             --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
             
       END;
       EXIT WHEN (csr_rcv_lines%NOTFOUND);
    END LOOP;           
    CLOSE csr_rcv_lines;



      
      -------------------------------------------------------------------------
      -- Extracting Shipment information for eligible PO Lines
      -------------------------------------------------------------------------
    OPEN csr_rcv_headers;
    
    LOOP
       FETCH csr_rcv_headers
       BULK COLLECT INTO gtab_jcpx_rcv_shpmnt_hdrs_tab LIMIT gn_commit_count;
    
       BEGIN
           FORALL ln_rec_count IN gtab_jcpx_rcv_shpmnt_hdrs_tab.FIRST .. gtab_jcpx_rcv_shpmnt_hdrs_tab.LAST
              INSERT INTO JCPX_RCV_MRCH_SHP_HDR_STG
                   VALUES gtab_jcpx_rcv_shpmnt_hdrs_tab (ln_rec_count);
                   
              gn_extract_rcv_h_success_cnt  := gn_extract_rcv_h_success_cnt + SQL%ROWCOUNT;
              
              COMMIT;
               
       EXCEPTION
          WHEN OTHERS THEN
         
            -- Any Exception, ROLLBACK the data
             ROLLBACK;
             
             ln_jcpx_receipts_err_count := SQL%BULK_EXCEPTIONS.COUNT;
             gn_extract_rcv_h_fail_cnt  := gn_extract_rcv_h_fail_cnt+ln_jcpx_receipts_err_count;
   
             lv_error_text := 'Error while Bulk Insert into Header Staging Table. Error Message:';
  
             FOR i IN 1 .. ln_jcpx_receipts_err_count
             LOOP
             
                lv_error_msg  := SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE);
                lv_error_text := lv_error_text||lv_error_msg;
  
                
             END LOOP;
            
             jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
             --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
             
       END;
       EXIT WHEN (csr_rcv_headers%NOTFOUND);
    END LOOP;           
    CLOSE csr_rcv_headers;
   
   EXCEPTION
      WHEN OTHERS THEN
         lv_error_text :=
                'Unexpected error while Extracting Receipt data. '
                || SQLERRM;
        
         jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
         --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
         
         pv_errbuf  := lv_error_text;
         pn_retcode := gn_error_retcode;
         
   
   END jcpx_extract_receipt_info;
   
   
   -- +===================================================================================+
   -- | Procedure Name: jcpx_re_extract_receipt_info                                      |
   -- | Description: This is the procedure which extracts the data from 11i               |
   -- |              instance through db linkswith process status as re-process           |
   -- |              and do the bulk collect of all the eligible records                  |
   -- |              into staging tables.                                                 |
   -- |                                                                                   |
   -- | Parameters : Type Description                                                     |
   -- |                                                                                   |
   -- |                                                                                   |
   -- | Change Record:                                                                    |
   -- | ==============                                                                    |
   -- |                                                                                   |
   -- | Ver      Date           Author             Description                            |
   -- |========= ============== ================= ================                        |
   -- | 0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        |
   -- +===================================================================================+
   
   PROCEDURE jcpx_re_extract_receipt_info(
                                           pv_errbuf   OUT VARCHAR2
                                          ,pn_retcode  OUT NUMBER
                                          ,Pv_Po_Header_id_From  IN     VARCHAR2
                                          ,Pv_po_header_id_to    IN     VARCHAR2
                                          ) 
   IS
     
      lv_error_text                 VARCHAR2(4000)                        := NULL;
      lv_error_msg                  VARCHAR2 (4000)                := NULL;
      
      TYPE t_jcpx_rcv_shipment_hdrs_tab IS TABLE OF   SHIPMENT_TXN_GT%ROWTYPE INDEX BY BINARY_INTEGER;
      gt_jcpx_rcv_shipment_hdrs_tab      t_jcpx_rcv_shipment_hdrs_tab;
      
      TYPE t_jcpx_rcv_shpmnt_lines_tab IS TABLE OF SHIPMENT_LIN_STG%ROWTYPE INDEX BY BINARY_INTEGER;
      gtab_jcpx_rcv_shpmnt_lns_tab      t_jcpx_rcv_shpmnt_lines_tab;
      
      
      TYPE t_jcpx_rcv_shpmnt_hdrs_tab IS TABLE OF JCPX_RCV_MRCH_SHP_HDR_STG%ROWTYPE INDEX BY BINARY_INTEGER;
      gtab_jcpx_rcv_shpmnt_hdrs_tab      t_jcpx_rcv_shpmnt_hdrs_tab;
	  
	  
      
      ln_rec_count                  NUMBER;
      ln_jcpx_receipts_err_count    NUMBER                                  := 0;
      
      CURSOR csr_rcv_gtemp
      IS
          SELECT rsh.last_update_date
                ,rsh.last_updated_by
                ,NULL --fu.user_name
                ,NULL --fu.start_date
                ,NULL --fu.end_date
                ,rsh.vendor_id
                ,pv.segment1 as vendor_num
                ,pv.vendor_name      
                ,rsh.vendor_site_id
				,NULL as VENDOR_SITE_CODE				
                ,rsl.ship_to_location_id      
                ,hl.location_code as ship_to_location_code
                ,hl.inventory_organization_id as ship_to_organization_id
                ,NULL as ship_to_organization_code
                ,gn_org_id as org_id
                ,NULL -- ou_name
                ,rsh.payment_terms_id
                ,(SELECT terms.name 
                    FROM apps.AP_TERMS_11I terms
                   WHERE terms.term_id = rsh.payment_terms_id) as payment_terms
                ,rsh.employee_id 
                ,ppf.employee_number
                ,ppf.full_name as employee_name
                ,rsh.shipment_header_id
                ,rsl.shipment_line_id
                ,rct.transaction_id
                ,NULL --rct.last_update_date as txn_last_update_date
                ,NULL --rct.last_updated_by as txn_last_update_by
                ,NULL --rct.request_id
                ,NULL --rct.program_application_id
                ,NULL --rct.program_id
                ,NULL --rct.program_update_date
                ,rsl.category_id
                ,rsl.item_id
                ,rct.employee_id as txn_employee_id
                ,rct.vendor_id as txn_vendor_id
                ,rct.vendor_site_id as txn_vendor_site_id
                ,rsl.from_organization_id
                ,rsl.to_organization_id
                ,rct.po_header_id
                ,pll.po_number
                ,rct.po_line_id
                ,pll.line_num as po_line_num
                ,rct.po_line_location_id
                ,pll.shipment_num
                ,rct.po_distribution_id
                ,(
                   SELECT distribution_num
                     FROM  PO_MRCH_DISTR_ALL_11I pd
                    WHERE pd.line_location_id = pll.line_location_id_11I
                      AND pd.po_line_id = pll.po_line_id_11I
                      AND pd.po_header_id = pll.po_header_id_11I
                 ) as po_distribution_num
                ,rct.destination_type_code
                ,rct.location_id
                ,rct.deliver_to_location_id
                ,rct.reason_id
                ,rct.transaction_type
                ,rct.transaction_date
                ,rct.attribute5
                ,(CASE 
		    WHEN ( NVL(pll.quantity_received,0) - NVL(pll.quantity_billed,0) ) <= 0
		      THEN pll.quantity_received
		    ELSE 
		      NVL(pll.quantity_received,0) - NVL(pll.quantity_billed,0)
		  END
                 ) as receipt_quantity                 
                 ------------------------------------------------------------
                ,pll.uom_code as uom
                ,pll.quantity
                ,pll.quantity_received
                ,pll.quantity_billed
                ,rct.quantity as txn_quantity
                ,pll.sum_inv_quantity
                ,rct.attribute1
				,rct.attribute2
                ,rct.attribute3
                ,rct.attribute4
				,rct.attribute5
                ,rct.attribute6
                ,rct.attribute7
                ,rct.attribute8
				,rct.attribute9
                ,rct.attribute10
                ,rct.attribute11
                ,rct.attribute12
                ,rct.attribute13
                ,rct.attribute14
				,pll.line_attribute1_r12
				,pll.line_attribute2_r12
				,NULL
				,NULL
				,pll.line_attribute5_r12
				,pll.line_attribute6_r12
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
                ,rsh.attribute1  hdr_attribute1
                ,rsh.attribute2  hdr_attribute2
                ,rsh.attribute3  hdr_attribute3
                ,rsh.attribute4  hdr_attribute4
                ,rsh.attribute5  hdr_attribute5
                ,rsh.attribute6  hdr_attribute6
                ,rsh.attribute7  hdr_attribute7
                ,rsh.attribute8  hdr_attribute8
                ,rsh.attribute9  hdr_attribute9
                ,rsh.attribute10 hdr_attribute10
                ,rsh.attribute11 hdr_attribute11
                ,pll.JCPX_PO_MRCH_POCONV_STG_ID 
           FROM   JCPX_PO_MRCH_POCONV_LIN_STG pll
                 ,apps.RCV_TRANSACTIONS_11I rct     -- Version 3.1
                 ,apps.RCV_SHIPMENT_HEADERS_11I rsh -- Version 3.1 
                 ,apps.RCV_SHIPMENT_LINES_11I rsl   -- Version 3.1
                 ,apps.PO_MRCH_VENDORS_11I pv
                 ,apps.PO_MRCH_VENDOR_SITES_11I pvs      
                 ,apps.HR_LOCATIONS_ALL_11I hl   
                 ,apps.PER_ALL_PEOPLE_F_11I ppf   
				 ,apps.PO_MRCH_HEADERS_ALL_11I poh
           WHERE pll.line_location_id_11I = rct.po_line_location_id
             AND pll.po_header_id_11I = rct.po_header_id      
             AND pll.po_line_id_11I = rct.po_line_id
             AND rct.shipment_header_id = rsh.shipment_header_id
             AND rct.shipment_line_id = rsl.shipment_line_id
             AND rsh.shipment_header_id = rsl.shipment_header_id
             AND rct.transaction_type = 'RECEIVE'
             --AND rct.attribute5 IS NULL commented for version 0.4
             AND ABS(ROUND((NVL(pll.quantity_received,0) -  NVL(pll.quantity_billed,0)),1)) <> 0
             AND pll.cancel_flag = 'N'
             AND rsh.vendor_id = pv.vendor_id
             AND rsh.vendor_site_id = pvs.vendor_site_id
             AND rsl.ship_to_location_id = hl.location_id
             AND rsh.employee_id = ppf.person_id(+)
             AND NVL(ppf.person_type_id,6) <> 9
             AND rsh.attribute9 IS NOT NULL
			 AND poh.PO_HEADER_ID = pll.PO_HEADER_ID_11I
			 AND poh.SEGMENT1 LIKE rsh.ATTRIBUTE9||'%'
			 AND pll.PROCESS_STATUS = 'SUCCESS'
             AND pll.JCPX_PO_MRCH_POCONV_STG_ID BETWEEN pv_po_header_id_from AND Pv_po_header_id_to
             AND EXISTS
                    (SELECT '1'
                       FROM SHIPMENT_LIN_STG rsl
                           ,JCPX_RCV_MRCH_SHP_HDR_STG rsh
                        WHERE rsh.shipment_header_id = rsl.shipment_header_id
                          AND pll.po_header_id_11I = rsl.po_header_id
                          AND pll.po_line_id_11I = rsl.po_line_id
                          AND pll.line_location_id_11I = rsl.po_line_location_id
                          AND (
                                   UPPER(rsh.process_status) = 'RE-PROCESS'
                                OR UPPER(rsl.process_status) = 'RE-PROCESS'
                              )
                    ) ;
      
      
      CURSOR csr_rcv_lines
            IS
                SELECT rct.shipment_header_id
                ,rct.shipment_line_id
                ,rct.transaction_id
                ,NULL
                ,NULL
                ,rct.last_update_date
                ,rct.last_updated_by
                ,NULL --fu.user_name
                ,NULL --fu.start_date
                ,NULL --fu.end_date
                ,NULL
                ,rct.request_id
                ,rct.program_application_id
                ,rct.program_id
                ,rct.program_update_date
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,rct.category_id
                ,mc.segment1 as category
                ,rct.item_id
                ,NULL
                ,NULL
                ,rct.employee_id
                ,ppf.employee_number
                ,ppf.full_name as employee_name
                ,rct.txn_vendor_id
                ,pv.segment1 as vendor
                ,pv.vendor_name
				,NULL AS VENDOR_SITE_ID_R12
				,phs.VENDOR_SITE_CODE
                ,rct.from_organization_id
                ,NULL as from_organization_code
                ,rct.to_organization_id
                ,NULL as to_organization_code
                ,rct.po_header_id
                ,rct.po_number
                ,rct.po_line_id
                ,rct.po_line_num
                ,rct.po_line_location_id
                ,rct.shipment_num
                ,rct.po_distribution_id
                ,rct.po_distribution_num
                ,rct.destination_type_code
                ,rct.location_id
                ,hl.location_code
                ,rct.deliver_to_location_id
                ,hl1.location_code deliverto
                ,rct.reason_id
                ,mr.reason_name
                ,gn_org_id as org_id
                ,NULL -- ou_name
                ,transaction_type
                ,transaction_date
                ,receipt_quantity
                ,uom
                ,rct.attribute5
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,'new'
                ,NULL
                ,'Extract'
                ,rsl.ATTRIBUTE1
                ,rsl.ATTRIBUTE2
                ,rsl.ATTRIBUTE3
                ,rsl.ATTRIBUTE4
                ,rsl.ATTRIBUTE5
                ,rsl.ATTRIBUTE6
                ,rsl.ATTRIBUTE7
                ,rsl.ATTRIBUTE8
                ,rsl.ATTRIBUTE9
                ,rsl.ATTRIBUTE10
                ,rsl.ATTRIBUTE11
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,rct.ATTRIBUTE1_11I_TXN
				,rct.ATTRIBUTE2_11I_TXN
				,rct.ATTRIBUTE3_11I_TXN
				,rct.ATTRIBUTE4_11I_TXN
				,rct.ATTRIBUTE5_11I_TXN
				,rct.ATTRIBUTE6_11I_TXN
				,rct.ATTRIBUTE7_11I_TXN
				,rct.ATTRIBUTE8_11I_TXN
				,rct.ATTRIBUTE9_11I_TXN
				,rct.ATTRIBUTE10_11I_TXN
				,rct.ATTRIBUTE11_11I_TXN
				,rct.ATTRIBUTE12_11I_TXN
				,rct.ATTRIBUTE13_11I_TXN
				,rct.ATTRIBUTE14_11I_TXN
				,rct.ATTRIBUTE1_R12_TXN
				,rct.ATTRIBUTE2_R12_TXN
				,rct.ATTRIBUTE3_R12_TXN
				,rct.ATTRIBUTE4_R12_TXN
				,rct.ATTRIBUTE5_R12_TXN
				,rct.ATTRIBUTE6_R12_TXN
				,rct.ATTRIBUTE7_R12_TXN
				,rct.ATTRIBUTE8_R12_TXN
				,rct.ATTRIBUTE9_R12_TXN
				,rct.ATTRIBUTE10_R12_TXN
				,rct.ATTRIBUTE11_R12_TXN
				,rct.ATTRIBUTE12_R12_TXN
				,rct.ATTRIBUTE13_R12_TXN
				,rct.ATTRIBUTE14_R12_TXN
				,rct.JCPX_PO_MRCH_POCONV_STG_ID 
          FROM  SHIPMENT_TXN_GT rct
				 ,apps.RCV_SHIPMENT_LINES_11I rsl
                 ,apps.AP_TERMS_11I terms
                 ,apps.PER_ALL_PEOPLE_F_11I ppf
                 ,apps.MTL_CATEGORIES_B_11I mc
                 ,apps.PO_MRCH_VENDORS_11I pv
                 ,apps.PO_MRCH_VENDOR_SITES_11I pvs
                 ,apps.HR_LOCATIONS_ALL_11I hl
                 ,apps.HR_LOCATIONS_ALL_11I hl1
                 ,apps.MTL_TRANSACTION_REASONS_11I mr
				 ,JCPX_PO_MRCH_POCONV_HDR_STG phs
           WHERE rct.SHIPMENT_HEADER_ID = rsl.SHIPMENT_HEADER_ID
		     AND rct.SHIPMENT_LINE_ID = rsl.SHIPMENT_LINE_ID
		     AND rct.txn_vendor_id = pv.vendor_id
             AND rct.txn_vendor_site_id = pvs.vendor_site_id
             AND rct.transaction_id = (
                                          SELECT MAX(transaction_id)
                                            FROM SHIPMENT_TXN_GT rct1
                                           WHERE rct.po_header_id =rct1.po_header_id
                                             AND rct.po_line_id= rct1.po_line_id
                                             AND rct.po_line_location_id = rct1.po_line_location_id
                                        )
             AND rct.location_id = hl.location_id(+)
             AND rct.payment_terms_id = terms.term_id(+)
             AND rct.category_id = mc.category_id (+)
             AND rct.txn_employee_id = ppf.person_id(+)
             AND NVL(ppf.person_type_id,6) <> 9
             AND rct.deliver_to_location_id = hl1.location_id (+)
             AND rct.reason_id = mr.reason_id (+)
			 AND phs.JCPX_PO_MRCH_POCONV_STG_ID = rct.JCPX_PO_MRCH_POCONV_STG_ID;
									   
									   
      CURSOR csr_rcv_headers
      IS
          SELECT DISTINCT
                 NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,rsh.last_update_date
                ,rsh.last_updated_by
                ,rsh.user_name
                ,rsh.start_date
                ,rsh.end_date
                ,rsh.vendor_id
                ,rsh.vendor_num
                ,rsh.vendor_name
                ,rsh.vendor_site_id
                ,rsl.vendor_site_code
                ,rsh.ship_to_location_id
                ,rsh.ship_to_location_code
                ,rsh.ship_to_organization_id
                ,rsh.ship_to_organization_code
                ,rsh.org_id
                ,rsh.ou_name
                ,rsh.payment_terms_id
                ,rsh.payment_terms
                ,rsh.employee_id
                ,rsh.employee_number
                ,rsh.employee_name
                ,rsh.shipment_header_id
                ,NULL
                ,NULL
                ,rsl.txn_vendor_site_id
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,NULL
                ,'new'
                ,NULL
                ,'Extract'
                ,rsh.HDR_ATTRIBUTE1
                ,rsh.HDR_ATTRIBUTE2
                ,rsh.HDR_ATTRIBUTE3
                ,rsh.HDR_ATTRIBUTE4
                ,rsh.HDR_ATTRIBUTE5
                ,rsh.HDR_ATTRIBUTE6
                ,rsh.HDR_ATTRIBUTE7
                ,rsh.HDR_ATTRIBUTE8
                ,rsh.HDR_ATTRIBUTE9
                ,rsh.HDR_ATTRIBUTE10
                ,rsh.HDR_ATTRIBUTE11
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
                ,rsh.JCPX_PO_MRCH_POCONV_STG_ID 
          FROM  SHIPMENT_TXN_GT rsh
              , SHIPMENT_LIN_STG rsl
          WHERE rsh.shipment_header_id = rsl.shipment_header_id;
      
   BEGIN
    
      -------------------------------------------------------------------------
      -- Re-Extracting Shipment information for eligible PO Lines
      -------------------------------------------------------------------------
      OPEN csr_rcv_gtemp;
      
      LOOP
         FETCH csr_rcv_gtemp
         BULK COLLECT INTO gt_jcpx_rcv_shipment_hdrs_tab LIMIT gn_commit_count;
      
         BEGIN
             FORALL ln_rec_count IN gt_jcpx_rcv_shipment_hdrs_tab.FIRST .. gt_jcpx_rcv_shipment_hdrs_tab.LAST
                INSERT INTO SHIPMENT_TXN_GT
                     VALUES gt_jcpx_rcv_shipment_hdrs_tab (ln_rec_count);
                     
                gn_extract_rcv_g_success_cnt := gn_extract_rcv_g_success_cnt + SQL%ROWCOUNT;
                
                COMMIT;
                 
         EXCEPTION
            WHEN OTHERS THEN
           
              -- Any Exception, ROLLBACK the data
               ROLLBACK;
               
               ln_jcpx_receipts_err_count := SQL%BULK_EXCEPTIONS.COUNT;
               gn_extract_rcv_g_fail_cnt  := gn_extract_rcv_g_fail_cnt+ln_jcpx_receipts_err_count;
     
               lv_error_text := 'Error while Bulk Insert into Global temporary Staging Table. Error Message:';
    
               FOR i IN 1 .. ln_jcpx_receipts_err_count
               LOOP
               
                  lv_error_msg  := SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE);
                  lv_error_text := lv_error_text||lv_error_msg;
    
                  
               END LOOP;
               
               jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
               --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
               
         END;
         EXIT WHEN (csr_rcv_gtemp%NOTFOUND);
      END LOOP;           
      CLOSE csr_rcv_gtemp;




      -------------------------------------------------------------------------
      -- Extracting Latest Shipment if Multiple shipments
      -------------------------------------------------------------------------
    OPEN csr_rcv_lines;
    
    LOOP
       FETCH csr_rcv_lines
       BULK COLLECT INTO gtab_jcpx_rcv_shpmnt_lns_tab LIMIT gn_commit_count;
    
       BEGIN
           FORALL ln_rec_count IN gtab_jcpx_rcv_shpmnt_lns_tab.FIRST .. gtab_jcpx_rcv_shpmnt_lns_tab.LAST
              INSERT INTO SHIPMENT_LIN_STG
                   VALUES gtab_jcpx_rcv_shpmnt_lns_tab (ln_rec_count);
                   
              gn_extract_rcv_l_success_cnt := gn_extract_rcv_l_success_cnt + SQL%ROWCOUNT;
              
              COMMIT;
               
       EXCEPTION
          WHEN OTHERS THEN
         
            -- Any Exception, ROLLBACK the data
             ROLLBACK;
             
             ln_jcpx_receipts_err_count := SQL%BULK_EXCEPTIONS.COUNT;
             gn_extract_rcv_l_fail_cnt  := gn_extract_rcv_l_fail_cnt+ln_jcpx_receipts_err_count;
   
             lv_error_text := 'Error while Bulk Insert into Lines Staging Table. Error Message:';
  
             FOR i IN 1 .. ln_jcpx_receipts_err_count
             LOOP
             
                lv_error_msg  := SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE);
                lv_error_text := lv_error_text||lv_error_msg;
  
                
             END LOOP;
             
             jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
             --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
             
       END;
       EXIT WHEN (csr_rcv_lines%NOTFOUND);
    END LOOP;           
    CLOSE csr_rcv_lines;



      
      -------------------------------------------------------------------------
      -- Extracting Shipment information for eligible PO Lines
      -------------------------------------------------------------------------
    OPEN csr_rcv_headers;
    
    LOOP
       FETCH csr_rcv_headers
       BULK COLLECT INTO gtab_jcpx_rcv_shpmnt_hdrs_tab LIMIT gn_commit_count;
    
       BEGIN
           FORALL ln_rec_count IN gtab_jcpx_rcv_shpmnt_hdrs_tab.FIRST .. gtab_jcpx_rcv_shpmnt_hdrs_tab.LAST
              INSERT INTO JCPX_RCV_MRCH_SHP_HDR_STG
                   VALUES gtab_jcpx_rcv_shpmnt_hdrs_tab (ln_rec_count);
                   
              gn_extract_rcv_h_success_cnt  := gn_extract_rcv_h_success_cnt + SQL%ROWCOUNT;
              
              COMMIT;
               
       EXCEPTION
          WHEN OTHERS THEN
         
            -- Any Exception, ROLLBACK the data
             ROLLBACK;
             
             ln_jcpx_receipts_err_count := SQL%BULK_EXCEPTIONS.COUNT;
             gn_extract_rcv_h_fail_cnt  := gn_extract_rcv_h_fail_cnt+ln_jcpx_receipts_err_count;
   
             lv_error_text := 'Error while Bulk Insert into Header Staging Table. Error Message:';
  
             FOR i IN 1 .. ln_jcpx_receipts_err_count
             LOOP
             
                lv_error_msg  := SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE);
                lv_error_text := lv_error_text||lv_error_msg;
  
                
             END LOOP;
           
             jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
             --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
             
       END;
       EXIT WHEN (csr_rcv_headers%NOTFOUND);
    END LOOP;           
    CLOSE csr_rcv_headers;	
   
   EXCEPTION
      WHEN OTHERS THEN
         lv_error_text :=
                'Unexpected error while Re-Extracting Receipt data. '
                || SQLERRM;

         jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
         --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
         
         pv_errbuf  := lv_error_text;
         pn_retcode := gn_error_retcode;
         
   
   END jcpx_re_extract_receipt_info; 
   
      
   -------------------------------------------------------------------------------
   -------------------------------------------------------------------------------
   -- Function   : jcpx_isvendor_exists_fn
   -- Description: This function takes the vendor name as input and check if
   --              vendor name exists and returns number. This is used for
   --              validating the vendor name exists or not.
   --
   -- Input Name                   Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Output Name                  Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Parameter Name               Description
   -- ===========================  ===============================================
   -- pv_vendor_name               Vendor Name
   -- pv_vendor_num                Vendor Number
   --
   -------------------------------------------------------------------------------
   -- Date        Programmer  Vers  Description
   -- =========== =========== ===== ==============================================
   -- | 0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                
   -------------------------------------------------------------------------------
      FUNCTION jcpx_isvendor_exists_fn (
                                        pv_vendor_name   apps.ap_suppliers.vendor_name%TYPE
                                       ,pv_vendor_num    apps.ap_suppliers.segment1%TYPE
                                       )
         RETURN NUMBER
      IS
         ln_vendor_id            apps.ap_suppliers.vendor_id%TYPE   DEFAULT 0;
        
         lv_error_text                VARCHAR2(4000)                        := NULL;
      BEGIN
        
         ln_vendor_id := 0;
         
         SELECT vendor_id
           INTO ln_vendor_id
           FROM apps.ap_suppliers
          WHERE segment1 = pv_vendor_num
           -- AND  UPPER (vendor_name) = UPPER (pv_vendor_name)
            AND  enabled_flag = 'Y'
            AND  NVL(start_date_active,sysdate) <= sysdate
            AND  NVL(end_date_active,sysdate) >= sysdate;
            
            
         RETURN ln_vendor_id;
         
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
       
           lv_error_text :=  'No Data found for Vendor Name ' 
	                                || pv_vendor_name
	                                ||'Vendor Number ' 
                             || pv_vendor_num ||'.'|| SQLERRM;
           jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
           ln_vendor_id := 0;
           RETURN ln_vendor_id;
         
         WHEN OTHERS THEN
       
            lv_error_text :=
	                      'Error in function jcpx_isvendor_exists_fn Message: '
	                  || ' Vendor Name Passed '
               || pv_vendor_name||'.'||SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            ln_vendor_id := 0;
            RETURN ln_vendor_id;
      END jcpx_isvendor_exists_fn;
   
   
   
   -------------------------------------------------------------------------------
   -------------------------------------------------------------------------------
   -- Function   : jcpx_isvendor_site_exists_fn
   -- Description: This function takes the vendor name as input and check if
   --              vendor site exists and returns number. This is used for
   --              validating the vendor site exists or not.
   --
   -- Input Name                   Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Output Name                  Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Parameter Name               Description
   -- ===========================  ===============================================
   -- pv_vendor_site_code          Vendor Name
   -- pv_vendor_id                 Vendor ID
   --
   -------------------------------------------------------------------------------
   -- | Ver      Date           Author             Description                            
   -- |========= ============== ================= ================                        
   -- | 0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                             
   -------------------------------------------------------------------------------
      FUNCTION jcpx_isvendor_site_exists_fn (
                                pv_vendor_id          apps.ap_suppliers.vendor_id%TYPE
                               ,pv_vendor_site_code   apps.ap_supplier_sites_all.vendor_site_code%TYPE
                               )
         RETURN NUMBER
      IS
         ln_vendor_site_id       apps.ap_supplier_sites_all.vendor_site_id%TYPE   DEFAULT 0;
         
         lv_error_text                VARCHAR2(4000)                        := NULL;
     BEGIN
        
         ln_vendor_site_id := 0;
         
         SELECT vendor_site_id
           INTO ln_vendor_site_id
           FROM apps.ap_supplier_sites_all
          WHERE vendor_id = pv_vendor_id
            AND UPPER (vendor_site_code) = UPPER (pv_vendor_site_code)
            AND NVL(inactive_date, sysdate + 1) > sysdate
            AND org_id = gn_org_id;
            
         RETURN ln_vendor_site_id;
         
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
        
	   lv_error_text :=  'No Data found for Vendor id ' 
	   	             || pv_vendor_id
	   	             ||'and Vendor Site Code ' 
	                     || pv_vendor_site_code ||'.'|| SQLERRM;
           jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
           ln_vendor_site_id := 0;
           RETURN ln_vendor_site_id;
         
         WHEN OTHERS THEN
        
	    lv_error_text :=  'Error in function jcpx_isvendor_site_exists_fn Message: '
	   	               ||' Vendor id ' 
	   	               || pv_vendor_id
	                       || ' Vendor site code Passed '
	                       || pv_vendor_site_code ||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            ln_vendor_site_id := 0;
            RETURN ln_vendor_site_id;
      END jcpx_isvendor_site_exists_fn;
      
      
   -------------------------------------------------------------------------------
   -------------------------------------------------------------------------------
   -- Function   : jcpx_is_location_fn
   -- Description: This function takes the location code and location type
   --              as input and derives the location id
   --
   -- Input Name                   Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Output Name                  Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Parameter Name               Description
   -- ===========================  ===============================================
   -- pv_location_code             location code
   -- pv_location_type             location type
   --
   -------------------------------------------------------------------------------
   --  Ver      Date           Author             Description                            
   -- ========= ============== ================= ================                        
   --  0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        
   -------------------------------------------------------------------------------
      FUNCTION jcpx_is_location_fn ( pv_location_code      IN  VARCHAR2
                                    ,pv_location_type      IN  VARCHAR2)
         RETURN NUMBER
      IS
         ln_location_id          NUMBER                        DEFAULT 0;
         
         lv_error_text                VARCHAR2(4000)                        := NULL;
         lv_location                  VARCHAR2 (60) := NULL;
      BEGIN
        
         ln_location_id := 0;
         
        
         
         IF UPPER(pv_location_code) = 'CORPORATE'
         THEN
    
             lv_location := pv_location_code;
        
         ELSE    
    
             lv_location := '0'||pv_location_code;
       
         END IF;         
         
         SELECT location_id
           INTO ln_location_id
           FROM apps.hr_locations_all
          WHERE location_code = lv_location
            AND NVL(inactive_date, sysdate + 1) > sysdate;
            
         RETURN ln_location_id;
      EXCEPTION
         
         WHEN NO_DATA_FOUND THEN
      
	    lv_error_text :=  'No Data found for '||pv_location_type||' location ' 
                              || pv_location_code
                              ||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            ln_location_id := 0;
            RETURN ln_location_id;
               
         WHEN OTHERS
         THEN
       
	    lv_error_text :=  'Error in function jcpx_is_location_fn Message: '
	    	   	               ||' for' 
	    	   	               || pv_location_type
	    	                       || 'location code '
	    	                       || pv_location_code ||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            ln_location_id := 0;
            RETURN ln_location_id;
      END jcpx_is_location_fn;
   
   
   -------------------------------------------------------------------------------
   -------------------------------------------------------------------------------
   -- Function   : jcpx_is_employee_num_fn
   -- Description: This function takes the employee number
   --              as input and derives the employee id
   --
   -- Input Name                   Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Output Name                  Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Parameter Name               Description
   -- ===========================  ===============================================
   -- pv_employee_num              employee number
   --
   -------------------------------------------------------------------------------
   --  Ver      Date           Author             Description                            
   -- ========= ============== ================= ================                        
   --  0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        
   -------------------------------------------------------------------------------
      FUNCTION jcpx_is_employee_num_fn ( pv_employee_name     IN VARCHAR2
                                        ,pv_employee_num      IN VARCHAR2)
         RETURN NUMBER
      IS
         ln_employee_id          NUMBER                        DEFAULT 0;
        
         lv_error_text                VARCHAR2(4000)                        := NULL;
      BEGIN
        
         ln_employee_id := 0;
         
         SELECT person_id
           INTO ln_employee_id
           FROM apps.per_all_people_f
          WHERE UPPER(full_name) = UPPER(pv_employee_name)
            AND person_type_id=6   
            AND effective_start_date <= sysdate
            AND effective_end_date >= sysdate;
   
         RETURN ln_employee_id;
      EXCEPTION
         
         WHEN NO_DATA_FOUND THEN
      
	    lv_error_text :=  'No Data found for employee ' 
                                          || pv_employee_num
	                                  ||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            ln_employee_id := 0;
            RETURN ln_employee_id;
               
         WHEN OTHERS
         THEN
       
	    lv_error_text :=  'Error in function jcpx_is_employee_num_fn Message: '
	    	    	       || 'employee number '
                               || pv_employee_num||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
           
            ln_employee_id := 0;
            RETURN ln_employee_id;
      END jcpx_is_employee_num_fn;
      
      
   -------------------------------------------------------------------------------
   -------------------------------------------------------------------------------
   -- Function   : jcpx_ispayment_terms_id_fn
   -- Description: This function takes the Payment terms id as input and returns
   --              number. This is used for validating the Payment terms id.
   --
   -- Input Name                   Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Output Name                  Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Parameter Name               Description
   -- ===========================  ===============================================
   -- pv_payment_terms_name        payment terms name
   --
   -------------------------------------------------------------------------------
   --  Ver      Date           Author             Description                            
   -- ========= ============== ================= ================                        
   --  0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        
   -------------------------------------------------------------------------------
      FUNCTION jcpx_ispayment_terms_id_fn (pv_payment_terms_name IN VARCHAR2)
         RETURN NUMBER
      IS
         ln_payment_terms_id_valid   apps.ap_terms.term_id%TYPE                     DEFAULT 0;
         
         lv_error_text                VARCHAR2(4000)                        := NULL;
      BEGIN
        
         ln_payment_terms_id_valid := 0;
         
         SELECT term_id
           INTO ln_payment_terms_id_valid
           FROM apps.ap_terms
          WHERE name = pv_payment_terms_name
            AND UPPER (enabled_flag) = 'Y';
   
         RETURN ln_payment_terms_id_valid;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
           ln_payment_terms_id_valid := 0;
     
	    lv_error_text := 'No data found for Payment terms name '
                              || pv_payment_terms_name||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
           RETURN ln_payment_terms_id_valid ;

         WHEN OTHERS THEN
     
	    lv_error_text :=  'Error in function jcpx_ispayment_terms_id_fn Message: '
	    	    	    	       || ' payment terms name '
	                               || pv_payment_terms_name||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            ln_payment_terms_id_valid := 0;
            RETURN ln_payment_terms_id_valid;
      END jcpx_ispayment_terms_id_fn;
   
   
   -------------------------------------------------------------------------------
   -------------------------------------------------------------------------------
   -- Function   : jcpx_is_item_fn
   -- Description: This function takes the 11i item id 
   --              as input and derives the item id from r12 setup
   --
   -- Input Name                   Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Output Name                  Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Parameter Name               Description
   -- ===========================  ===============================================
   -- pv_item_id                   11i item id
   --
   -------------------------------------------------------------------------------
   --  Ver      Date           Author             Description                            
   -- ========= ============== ================= ================                        
   --  0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        
   -------------------------------------------------------------------------------
      FUNCTION jcpx_is_item_fn ( pv_item_id  IN   NUMBER)
         RETURN NUMBER
      IS
         ln_new_item_id              NUMBER;
         
         ln_segment1             VARCHAR2(50)                                   :='0';
         ln_segment2             VARCHAR2(50)                                   :='0';
         
        
         lv_error_text                VARCHAR2(4000)                        := NULL;
      BEGIN
       
         ln_new_item_id := 0;
         ln_segment1 := NULL;
         ln_segment2 := NULL;
         
         BEGIN 
            SELECT inventory_item_id
              INTO ln_new_item_id
              FROM mtl_system_items_b msi
             WHERE msi.segment1 = ln_segment1
               AND msi.segment2 = ln_segment2;
         EXCEPTION
            WHEN OTHERS THEN
          
               ln_new_item_id := 0;
            
	       lv_error_text := 'Others Error for item validation while getting r12 item id'
	       		                                    ||pv_item_id||' Item'||'.'|| SQLERRM;
               jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
         END;
            
         RETURN ln_new_item_id;
            
      EXCEPTION
         WHEN OTHERS
         THEN
           
            ln_new_item_id := 0;
            RETURN ln_new_item_id;
            
            
      END jcpx_is_item_fn;
   
   
   
   -------------------------------------------------------------------------------
   -------------------------------------------------------------------------------
   -- Function   : jcpx_is_category_fn
   -- Description: This function takes the category name
   --              as input and derives the category id from r12 setup
   --
   -- Input Name                   Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Output Name                  Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Parameter Name               Description
   -- ===========================  ===============================================
   -- pv_category                  category name
   --
   -------------------------------------------------------------------------------
   --  Ver      Date           Author             Description                            
   --  ========= ============== ================= ================                       
   --  0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        
   -------------------------------------------------------------------------------
      FUNCTION jcpx_is_category_fn (pv_category      IN   VARCHAR2)
         RETURN NUMBER
      IS
         ln_category_id          NUMBER;
        
         lv_error_text                VARCHAR2(4000)                        := NULL;
      BEGIN
       
         ln_category_id  := 0;
         
        
         
         SELECT mcb.category_id
           INTO ln_category_id
	   FROM apps.mtl_categories_b mcb
	       ,apps.mtl_category_sets_vl mcs 
	       ,apps.mtl_category_set_valid_cats mcsvc
	  WHERE mcb.enabled_flag = 'Y'
	    AND mcsvc.category_id = mcb.category_id
	    AND mcsvc.category_set_id = mcs.category_set_id      
	    AND mcs.category_set_name = 'Inventory'
	    AND UPPER(mcb.segment1) = UPPER(pv_category);

         
         RETURN ln_category_id;
      EXCEPTION
         
         WHEN NO_DATA_FOUND THEN
     
	    lv_error_text := 'No Data found for category ' 
                             || pv_category||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);                             
            ln_category_id  := 0;
            RETURN ln_category_id;
               
         WHEN OTHERS THEN
     
	    lv_error_text := 'Error in function jcpx_is_category_fn Message: '
	       		    || 'category name '
                            || pv_category||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);                            
            ln_category_id  := 0;
            RETURN ln_category_id;
      END jcpx_is_category_fn;


   -------------------------------------------------------------------------------
   -------------------------------------------------------------------------------
   -- Function   : jcpx_is_last_update_by_fn
   -- Description: This function takes the last_update_by name
   --              as input and derives the last_update_by id from r12 setup
   --
   -- Input Name                   Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Output Name                  Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Parameter Name               Description
   -- ===========================  ===============================================
   -- pv_last_update_by                      last_update_by name
   --
   -------------------------------------------------------------------------------
   --  Ver      Date           Author             Description                            
   -- ========= ============== ================= ================                        
   --  0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        
   -------------------------------------------------------------------------------
      FUNCTION jcpx_is_last_update_by_fn (pv_last_update_by      IN VARCHAR2)
         RETURN NUMBER
      IS
         ln_last_update_by_id          NUMBER                        DEFAULT 0;
        
         lv_error_text                VARCHAR2(4000)                        := NULL;
      BEGIN
      
         ln_last_update_by_id := 0;
         
         SELECT user_id
           INTO ln_last_update_by_id
           FROM apps.fnd_user
          WHERE  user_name = pv_last_update_by
            AND  NVL(start_date,sysdate) <= sysdate
            AND  NVL(end_date,sysdate) >= sysdate;
   
         RETURN ln_last_update_by_id;
      EXCEPTION
         
         WHEN NO_DATA_FOUND THEN
           
            ln_last_update_by_id := 0;
        
	    lv_error_text := 'No Data found for last_update_by ' 
                                       || pv_last_update_by||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            RETURN ln_last_update_by_id;
               
         WHEN OTHERS
         THEN
    
	    lv_error_text := 'Error in function jcpx_is_last_update_by_fn Message: '
	 	       		||'last_update_by name '
                                || pv_last_update_by||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
         RETURN ln_last_update_by_id;
      END jcpx_is_last_update_by_fn;
   
   
   -------------------------------------------------------------------------------
   -------------------------------------------------------------------------------
   -- Function   : jcpx_receipt_uom_validation_fn
   -- Description: This function takes the primary_uom_code as input and
   --              check if it is present in mtl system
   --
   -- Input Name                   Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Output Name                  Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Parameter Name               Description
   -- ===========================  ===============================================
   -- pv_receipt_uom_code              Primary_Uom_Code
   --
   -------------------------------------------------------------------------------
   --  Ver      Date           Author             Description                            
   -- ========= ============== ================= ================                        
   --  0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        
   -------------------------------------------------------------------------------
     
      FUNCTION jcpx_receipt_uom_validation_fn(pv_receipt_uom_code     mtl_units_of_measure_tl.uom_code%TYPE)
      RETURN VARCHAR2
      IS
        lv_uom_code             mtl_units_of_measure_tl.uom_code%TYPE ;
        
        lv_error_text                VARCHAR2(4000)                        := NULL;
      BEGIN
     
        lv_uom_code := NULL;
     
        SELECT uom_code
          INTO lv_uom_code
          FROM apps.mtl_units_of_measure
         WHERE uom_code =  pv_receipt_uom_code
           AND NVL(disable_date, sysdate + 1) > sysdate;
        RETURN lv_uom_code;
     
        EXCEPTION
         WHEN NO_DATA_FOUND THEN
           lv_uom_code := NULL;
     
	   lv_error_text := 'No data found for UOM code '
                            || pv_receipt_uom_code||'.'|| SQLERRM;
           jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
        RETURN lv_uom_code;
     
        WHEN OTHERS THEN
    
	    lv_error_text := 'Error in function jcpx_receipt_uom_validation_fn Message: '
	  	 	     || ' UOM code Passed '
                             || pv_receipt_uom_code||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
          lv_uom_code := NULL;
        RETURN lv_uom_code;
 END jcpx_receipt_uom_validation_fn;
   
   
   -------------------------------------------------------------------------------
   -------------------------------------------------------------------------------
   -- Function   : jcpx_is_po_num_fn
   -- Description: This function takes the po number
   --              as input and derives the po header id
   --
   -- Input Name                   Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Output Name                  Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Parameter Name               Description
   -- ===========================  ===============================================
   -- pv_po_num                    po number
   --
   -------------------------------------------------------------------------------
   --  Ver      Date           Author             Description                            
   -- ========= ============== ================= ================                        
   --  0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        
   -------------------------------------------------------------------------------
      FUNCTION jcpx_is_po_num_fn (pv_po_num      IN VARCHAR2)
         RETURN NUMBER
      IS
         ln_po_header_id          NUMBER                                        DEFAULT 0;
         
         lv_error_text                VARCHAR2(4000)                        := NULL;
      BEGIN
       
         ln_po_header_id := 0;
         
         SELECT po_header_id
           INTO ln_po_header_id 
           FROM apps.po_headers_all
          WHERE segment1 = pv_po_num
            AND authorization_status         = 'APPROVED'
            AND enabled_flag = 'Y'
            AND NVL(start_date_active,sysdate) <= sysdate
            AND NVL(end_date_active,sysdate) >= sysdate 
            AND org_id = gn_org_id;

   
         RETURN ln_po_header_id;
      EXCEPTION
         
         WHEN NO_DATA_FOUND THEN
    
	    lv_error_text := 'No Data found for po ' 
                              || pv_po_num||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            ln_po_header_id := 0;
            RETURN ln_po_header_id;
               
         WHEN OTHERS
         THEN
     
	    lv_error_text := 'Error in function jcpx_is_po_num_fn Message: '
	    	  	 	|| 'po number '
                                || pv_po_num||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            RETURN ln_po_header_id;
      END jcpx_is_po_num_fn;
   
   
   
   -- +===================================================================================+
   -- | Procedure Name: jcpx_is_po_proc                                                   |
   -- | Description: This procedure takes the po line number, shipment number,            |
   -- |              po distribution number and po header id                              |
   -- |              as input and derives the po line id, item description,               |
   -- |              line location id, po distribution id, quantity,                      |
   -- |              quantity received and quantity billed from r12 setup.                |
   -- |                                                                                   |
   -- | Parameters : Type Description                                                     |
   -- |                                                                                   |
   -- | pv_po_line_num              IN         NUMBER                                     |
   -- | pv_shipment_num             IN         NUMBER                                     |
   -- | pv_po_distribution_num      IN         NUMBER                                     |
   -- | pv_po_header_id             IN         NUMBER                                     |
   -- | pv_po_line_id               OUT        NUMBER                                     |
   -- | pv_item_description         OUT        VARCHAR2                                   |
   -- | pv_line_location_id         OUT        NUMBER                                     |
   -- | pv_po_distribution_id       OUT        NUMBER                                     |
   -- | pv_quantity                 OUT        NUMBER                                     |
   -- | pv_quantity_received        OUT        NUMBER                                     |
   -- | pv_quantity_billed          OUT        NUMBER                                     |
   -- |                                                                                   |
   -- | Change Record:                                                                    |
   -- | ==============                                                                    |
   -- |                                                                                   |
   -- | Ver      Date           Author             Description                            |
   -- |========= ============== ================= ================                        |
  -- | 0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        |
   -- +===================================================================================+
      PROCEDURE jcpx_is_po_proc ( pv_po_line_num              IN         NUMBER
                                 ,pv_shipment_num             IN         NUMBER
                                 ,pv_po_distribution_num      IN         NUMBER
                                 ,pv_po_header_id             IN         NUMBER
                                 ,pv_po_line_id               OUT        NUMBER
                                 ,pv_item_description         OUT        VARCHAR2
                                 ,pv_line_location_id         OUT        NUMBER
                                 ,pv_po_distribution_id       OUT        NUMBER
                                 ,pv_quantity                 OUT        NUMBER
                                 ,pv_quantity_received        OUT        NUMBER
                                 ,pv_quantity_billed          OUT        NUMBER
                                 )
      IS
         
         lv_error_text                VARCHAR2(4000)                        := NULL;
      BEGIN
        
         pv_po_line_id           := 0;
         pv_item_description     := NULL;
         pv_line_location_id     := 0;
         pv_po_distribution_id   := 0;
         pv_quantity             := 0;
         pv_quantity_received    := 0;
         pv_quantity_billed      := 0;
         
         SELECT   pl.po_line_id
                 ,pl.item_description
                 ,pll.line_location_id
                 ,pd.po_distribution_id
                 ,pll.quantity
                 ,pll.quantity_received
                 ,pll.quantity_billed
         INTO    pv_po_line_id
                ,pv_item_description
                ,pv_line_location_id
                ,pv_po_distribution_id
                ,pv_quantity
                ,pv_quantity_received
                ,pv_quantity_billed
         FROM   apps.po_lines_all pl
               ,apps.po_line_locations_all pll
               ,apps.po_distributions_all pd
         WHERE   line_num = pv_po_line_num
           AND   shipment_num = pv_shipment_num
           AND   distribution_num = pv_po_distribution_num 
           AND   pl.po_header_id = pv_po_header_id
           AND   pl.po_header_id = pll.po_header_id
           AND   pl.po_line_id = pll.po_line_id
           AND   pl.po_header_id = pd.po_header_id
           AND   pl.po_line_id = pd.po_line_id
           AND   pll.line_location_id = pd. line_location_id 
           AND   pl.org_id = gn_org_id
           AND   pll.org_id = gn_org_id
           AND   pd.org_id = gn_org_id;

            
      EXCEPTION
         
         WHEN NO_DATA_FOUND THEN
          
             pv_po_line_id           := 0;
             pv_item_description     := NULL;
             pv_line_location_id     := 0;
             pv_po_distribution_id   := 0;
             pv_quantity             := 0;
             pv_quantity_received    := 0;
             pv_quantity_billed      := 0;
             
        
	    lv_error_text := 'No Data found for po line number ' 
                            || pv_po_line_num
                            ||'shipment number  ' 
                            || pv_shipment_num
                            ||'po distribution no  ' 
                            || pv_po_distribution_num
                            ||'po header id ' 
                            || pv_po_header_id||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
                         
             
         WHEN OTHERS
         THEN
          
             pv_po_line_id           := 0;
             pv_item_description     := NULL;
             pv_line_location_id     := 0;
             pv_po_distribution_id   := 0;
             pv_quantity             := 0;
             pv_quantity_received    := 0;
             pv_quantity_billed      := 0;
             
       
	    lv_error_text := 'Error in procedure jcpx_is_po_proc Message: '
	     	    	    || 'po line number ' 
                            || pv_po_line_num
                            ||'shipment number  ' 
                            || pv_shipment_num
                            ||'po distribution no  ' 
                            || pv_po_distribution_num
                            ||'po header id ' 
                            || pv_po_header_id||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            
      END jcpx_is_po_proc;
   
   
   -------------------------------------------------------------------------------
   -------------------------------------------------------------------------------
   -- Function  : jcpx_is_ou_fn
   -- Description: This function takes the operating unit name 
   --              as input and derives the org id from r12 setup
   --
   -- Input Name                   Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Output Name                  Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Parameter Name               Description
   -- ===========================  ===============================================
   -- pv_ou_name                   operating unit name
   -- pv_org_id                    Organization id
   --
   -------------------------------------------------------------------------------
   --  Ver      Date           Author             Description                            
   -- ========= ============== ================= ================                        
   --  0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version 
   -------------------------------------------------------------------------------
      FUNCTION   jcpx_is_ou_fn ( pv_ou_name  IN   VARCHAR2)
      RETURN NUMBER
      IS
         lv_org_id               NUMBER;
        
         lv_error_text                VARCHAR2(4000)                        := NULL;
      BEGIN
        
         lv_org_id := 0;
         
         SELECT organization_id
         INTO lv_org_id
         FROM hr_operating_units
         WHERE name = pv_ou_name
           AND NVL(date_from,sysdate) <= sysdate
           AND NVL(date_to,sysdate) >= sysdate ;
         
         RETURN lv_org_id;
      EXCEPTION
         
         WHEN NO_DATA_FOUND THEN
      
	    lv_error_text := 'No Data found for operating unit name ' 
                             || pv_ou_name||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            lv_org_id := 0;
            RETURN lv_org_id;
            
         WHEN OTHERS
         THEN
      
	    lv_error_text := 'Error in function jcpx_is_ou_fn Message: '
	    	    	  	 	|| 'for operating unit name  '
	                                || pv_ou_name||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            lv_org_id := 0;
            RETURN lv_org_id;
            
      END jcpx_is_ou_fn;
   
   
   -------------------------------------------------------------------------------
   -------------------------------------------------------------------------------
   -- Function   : jcpx_is_organization_fn
   -- Description: This function takes the operating unit id, ship to organization
   --              code and organization type as input and derives 
   --              ship to org id from r12 setup
   --
   -- Input Name                   Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Output Name                  Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Parameter Name               Description
   -- ===========================  ===============================================
   -- pv_ou_id                     operating unit id
   -- pv_organization_code ship to Organization code
   -- pv_organization_type         organization type
   --
   -------------------------------------------------------------------------------
   --  Ver      Date           Author             Description                            
   -- ========= ============== ================= ================                        
   --  0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version 
   -------------------------------------------------------------------------------
      FUNCTION jcpx_is_organization_fn ( pv_ou_id              IN   NUMBER
                                        ,pv_organization_code  IN   VARCHAR2
                                        ,pv_organization_type  IN   VARCHAR2)
      RETURN NUMBER
      IS
         lv_organization_id              NUMBER;
       
         lv_error_text                VARCHAR2(4000)                        := NULL;
      BEGIN
      
         lv_organization_id := 0;
         
         SELECT organization_id
         INTO lv_organization_id
         FROM apps.org_organization_definitions 
         WHERE operating_unit = pv_ou_id
           AND organization_code = pv_organization_code
           AND NVL(disable_date,sysdate) >= sysdate;
         
         RETURN lv_organization_id;
      EXCEPTION
         
         WHEN NO_DATA_FOUND THEN
          
            lv_organization_id := 0;
          
	    lv_error_text := 'No Data found for operating unit id ' 
                             || pv_ou_id
                             ||'and '
                             ||pv_organization_type
                             ||' organization code '
                             || pv_organization_code||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            RETURN lv_organization_id;
            
         WHEN OTHERS
         THEN
           
            lv_organization_id := 0;
      
	    lv_error_text := 'Error in function jcpx_is_organization_fn Message: '
	    	    	    	  	 	|| 'for operating unit id  '
	    	                                || pv_ou_id
                             ||'and '
                             ||pv_organization_type
                             ||' organization code '
                             || pv_organization_code||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            RETURN lv_organization_id;
            
      END jcpx_is_organization_fn;
   
   
   -------------------------------------------------------------------------------
   -------------------------------------------------------------------------------
   -- Function   : jcpx_isuser_exists_fn
   -- Description: This function takes the user name as input and check if
   --              user name exists and returns number. This is used for
   --              validating the user name exists or not.
   --
   -- Input Name                   Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Output Name                  Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Parameter Name               Description
   -- ===========================  ===============================================
   -- pv_user_name                 user Name
   --
   -------------------------------------------------------------------------------
   --  Ver      Date           Author             Description                            
   -- ========= ============== ================= ================                        
   --  0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version 
   -------------------------------------------------------------------------------
      FUNCTION jcpx_isuser_exists_fn (
                                      pv_user_name   apps.fnd_user.user_name%TYPE
                                   )
         RETURN NUMBER
      IS
         ln_user_id              apps.fnd_user.user_id%TYPE   DEFAULT 0;
         
         lv_error_text                VARCHAR2(4000)                        := NULL;
      BEGIN
       
         ln_user_id := 0;
         
         SELECT user_id
           INTO ln_user_id
           FROM apps.fnd_user
          WHERE  UPPER (user_name) = UPPER (pv_user_name)
            AND  NVL(start_date,sysdate) <= sysdate
            AND  NVL(end_date,sysdate) >= sysdate;
            
         RETURN ln_user_id;
         
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
       
           ln_user_id := 0;
        
	   lv_error_text :=  'No Data found for User name ' 
                             || pv_user_name||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
           RETURN ln_user_id;
         
         WHEN OTHERS THEN
    
	    lv_error_text := 'Error in function jcpx_isuser_exists_fn Message: '
	    	    	       ||' user Name Passed '
                               || pv_user_name||'.'|| SQLERRM;
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            ln_user_id := 0;
            RETURN ln_user_id;
      END jcpx_isuser_exists_fn;
   
   
   -------------------------------------------------------------------------------
   -------------------------------------------------------------------------------
   -- Function   : jcpx_isreason_exists_fn
   -- Description: This function takes the reason name as input and check if
   --              reason name exists and returns number. This is used for
   --              validating the reason name exists or not.
   --
   -- Input Name                   Description
   -- ===========================  ===============================================
   -- None                         None
   --
   --  Output Name                  Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Parameter Name               Description
   -- ===========================  ===============================================
   -- pv_reason_name                 reason Name
   --
   -------------------------------------------------------------------------------
   --  Ver      Date           Author             Description                            
    -- ========= ============== ================= ================                        
    --  0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version 
   -------------------------------------------------------------------------------
      FUNCTION jcpx_isreason_exists_fn ( pv_reason_name   mtl_transaction_reasons.reason_name%TYPE
                                       )
         RETURN NUMBER
      IS
         ln_reason_id            mtl_transaction_reasons.reason_id%TYPE;
       
         lv_error_text                VARCHAR2(4000)                        := NULL;
      BEGIN
       
         ln_reason_id := 0;
         
         SELECT reason_id
           INTO ln_reason_id
           FROM mtl_transaction_reasons
          WHERE  UPPER (reason_name) = UPPER (pv_reason_name);
            
         RETURN ln_reason_id;
         
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
        
           ln_reason_id := 0;
       
	   lv_error_text := 'No Data found for reason name ' 
                             || pv_reason_name||'.'|| SQLERRM;
	   jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
           RETURN ln_reason_id;
         
         WHEN OTHERS THEN
           
            ln_reason_id := 0;
      
	    lv_error_text := 'Error in function jcpx_isreason_exists_fn Message: '
	    	    	    	   ||' reason Name Passed '
                                   || pv_reason_name ||'.'|| SQLERRM;
	    jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            RETURN ln_reason_id;
      END jcpx_isreason_exists_fn;
      
   -------------------------------------------------------------------------------
   -------------------------------------------------------------------------------
   -- Function   : jcpx_isperiod_open_fn
   -- Description: This function checks if the Purchasing period is open for 
   --              SYSDATE and returns 1 if open and 0 if close. This is used for
   --              validating if the purchasing period is open or not.
   --
   -- Input Name                   Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Output Name                  Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Parameter Name               Description
   -- ===========================  ===============================================
   --
   -------------------------------------------------------------------------------
   --  Ver      Date           Author             Description                            
   -- ========= ============== ================= ================                        
   --  0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version 
   -------------------------------------------------------------------------------
      FUNCTION jcpx_isperiod_open_fn 
         RETURN NUMBER
      IS
         ln_period_open          NUMBER                                    DEFAULT 0;
        
         lv_error_text                VARCHAR2(4000)                        := NULL;
      BEGIN
        
         ln_period_open := 0;
         
         SELECT COUNT(1)
           INTO ln_period_open
           FROM fnd_application a
               ,gl_period_statuses b
           WHERE a.application_id=b.application_id
             AND a.APPLICATION_SHORT_NAME ='PO'
	     AND b.set_of_books_id = gn_set_of_books_id
	     AND closing_status = 'O'
	     AND start_date < =TRUNC(SYSDATE)    --Modified Version 3.2
             AND end_date > TRUNC(SYSDATE);
            
            
         RETURN ln_period_open;
         
      EXCEPTION
         
         WHEN OTHERS THEN
    
	    lv_error_text := 'Error in function jcpx_isperiod_open_fn Message: '
	    	    	    	    	   ||' Set of book id '
	                                    || gn_set_of_books_id ||'.'|| SQLERRM;
	    jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            ln_period_open := 0;
            RETURN ln_period_open;
      END jcpx_isperiod_open_fn;
	  
	  
-------------------------------------------------------------------------------
   -------------------------------------------------------------------------------
   -- Function   : jcpx_IsInvAccperiod_open_fn
   -- Description: This function checks if the Inventory Accounting period is open for 
   --              SYSDATE and returns 1 if open and 0 if close. This is used for
   --              validating if the purchasing period is open or not.
   --
   -- Input Name                   Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Output Name                  Description
   -- ===========================  ===============================================
   -- None                         None
   --
   -- Parameter Name               Description
   -- ===========================  ===============================================
   --
   -------------------------------------------------------------------------------
   --  Ver      Date           Author             Description                            
   -- ========= ============== ================= ================                        
   --  0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version 
   -------------------------------------------------------------------------------
      FUNCTION jcpx_IsInvAccperiod_open_fn 
         RETURN NUMBER
      IS
         ln_period_open          NUMBER                                    DEFAULT 0;
        
         lv_error_text                VARCHAR2(4000)                        := NULL;
      BEGIN
        
         ln_period_open := 0;
         
        SELECT COUNT(1)
		INTO ln_period_open
		FROM org_acct_periods oap ,
			 org_organization_definitions ood
		WHERE oap.organization_id = ood.organization_id
		AND (TRUNC(SYSDATE) BETWEEN TRUNC(oap.period_start_date) AND TRUNC (oap.schedule_close_date))
		AND UPPER(ood.organization_code) = 'DMI';
                        
       RETURN ln_period_open;
         
      EXCEPTION
         
         WHEN OTHERS THEN
    
	    lv_error_text := 'Error in function jcpx_IsInvAccperiod_open_fn Message: '
	    	    	    	    	   ||' Set of book id '
	                                    || gn_set_of_books_id ||'.'|| SQLERRM;
	    jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            ln_period_open := 0;
            RETURN ln_period_open;
      END jcpx_IsInvAccperiod_open_fn;	  
   
   
   
   -- +===================================================================================+
   -- | Procedure Name: jcpx_validate_receipt_info                                        |
   -- | Description: This is the procedure which picks up all the eligible                |
   -- |              records from staging tables and calls the various                    |
   -- |              package procedures and functions to validate the Receipt             |
   -- |              records. Once all the required validations are done, the data        |
   -- |              is updated back to the staging tables with derived values.           |
   -- |                                                                                   |
   -- | Parameters : Type Description                                                     |
   -- |                                                                                   |
   -- | pv_shpmnt_hdr_from IN NUMBER                                                      |
   -- | pv_shpmnt_hdr_to   IN NUMBER                                                      |
   -- |                                                                                   |
   -- | Change Record:                                                                    |
   -- | ==============                                                                    |
   -- |                                                                                   |
   -- | Ver      Date           Author             Description                            |
   -- |========= ============== ================= ================                        |
   -- | 0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        |
   -- +===================================================================================+
   
   PROCEDURE jcpx_validate_receipt_info (
                                          pv_errbuf   OUT VARCHAR2
                                         ,pn_retcode  OUT NUMBER
                                         ,pv_shpmnt_hdr_from IN NUMBER
                                         ,pv_shpmnt_hdr_to IN NUMBER
                                         )
   IS
      
      lv_error_text                VARCHAR2(4000)                        := NULL;
      lv_error_message              VARCHAR2(1000 Byte)                      DEFAULT NULL;
      lv_quantity                   NUMBER;
      lv_quantity_received          NUMBER;
      lv_quantity_billed            NUMBER;
      ln_organization_id            org_organization_definitions.organization_id%TYPE;
      ln_def_category_id            NUMBER;
      ln_receipt_count              NUMBER;
      ln_period_open                NUMBER;
	  ln_inv_acc_period_open		NUMBER;
      
      ln_term_id                    NUMBER;        
      lv_payment_term               VARCHAR2(50);  
	  
	  ln_val_err_hdr_count			NUMBER;
      
      TYPE t_jcpx_rcv_shpmnt_lines_rec IS RECORD( shipment_header_id             NUMBER
                                                 ,shipment_line_id                NUMBER
                                                 ,transaction_id                  NUMBER
                                                 ,interface_transaction_id        NUMBER
                                                 ,group_id                        NUMBER
                                                 ,last_update_date                DATE
                                                 ,last_updated_by                 NUMBER
                                                 ,user_name                       VARCHAR2(100 )
                                                 ,start_date                      DATE
                                                 ,end_date                        DATE
                                                 ,created_by                      NUMBER
                                                 ,request_id                      NUMBER
                                                 ,program_application_id          NUMBER
                                                 ,program_id                      NUMBER
                                                 ,program_update_date             DATE
                                                 ,processing_status_code          VARCHAR2(25 )
                                                 ,processing_mode_code           VARCHAR2(25 )
                                                 ,receipt_source_code             VARCHAR2(25 )
                                                 ,processing_request_id           NUMBER
                                                 ,transaction_status_code         VARCHAR2(25 )
                                                 ,category_id                     NUMBER
                                                 ,category                        VARCHAR2(40 )
                                                 ,item_id                         NUMBER
                                                 ,item                            VARCHAR2(40 )
                                                 ,item_description                VARCHAR2 (240 )
                                                 ,employee_id                     NUMBER(9)
                                                 ,employee_number                 VARCHAR2(30 )
                                                 ,employee_name                   VARCHAR2(240 )
                                                 ,txn_vendor_id                   NUMBER
                                                 ,vendor                          VARCHAR2(30 )
                                                 ,vendor_name                     VARCHAR2(240 )
                                                 ,txn_vendor_site_id              NUMBER
                                                 ,vendor_site_code                VARCHAR2(15 )
                                                 ,from_organization_id            NUMBER
                                                 ,from_organization_code          VARCHAR2(3 )
                                                 ,to_organization_id              NUMBER
                                                 ,to_organization_code            VARCHAR2(3 )
                                                 ,po_header_id                    NUMBER
                                                 ,po_number                       VARCHAR2(20 )
                                                 ,po_line_id                      NUMBER
                                                 ,po_line_num                     NUMBER
                                                 ,po_line_location_id             NUMBER
                                                 ,shipment_num                    NUMBER
                                                 ,po_distribution_id              NUMBER
                                                 ,po_distribution_num             NUMBER
                                                 ,destination_type_code           VARCHAR2(25 )
                                                 ,location_id                     NUMBER
                                                 ,location_code                   VARCHAR2(60 )
                                                 ,deliver_to_location_id          NUMBER
                                                 ,deliverto                       VARCHAR2(60 )
                                                 ,reason_id                       NUMBER
                                                 ,reason_name                     VARCHAR2(30 )
                                                 ,org_id                          NUMBER
                                                 ,ou_name                         VARCHAR2(240 )
                                                 ,transaction_type                VARCHAR2(25 )
                                                 ,transaction_date                DATE
                                                 ,receipt_quantity                NUMBER
                                                 ,uom                             VARCHAR2(3 )
                                                 ,attribute5                      VARCHAR2 (150 )
                                                 ,source_document_code            VARCHAR2(25 )
                                                 ,header_interface_id             NUMBER
                                                 ,category_id_r12                 NUMBER
                                                 ,item_id_r12                     NUMBER
                                                 ,employee_id_r12                 NUMBER
                                                 ,txn_vendor_id_r12               NUMBER
                                                 ,txn_vendor_site_id_r12          NUMBER
                                                 ,from_organization_id_r12        NUMBER
                                                 ,to_organization_id_r12          NUMBER
                                                 ,po_header_id_r12                NUMBER
                                                 ,po_line_id_r12                  NUMBER
                                                 ,po_line_location_id_r12         NUMBER
                                                 ,po_distribution_id_r12          NUMBER
                                                 ,location_id_r12                 NUMBER
                                                 ,deliver_to_location_id_r12      NUMBER
                                                 ,reason_id_r12                   NUMBER
                                                 ,org_id_r12                      NUMBER
                                                 ,user_id_r12                     NUMBER
                                                 ,uom_r12                         VARCHAR2(3)
                                                 ,process_status                  VARCHAR2(100 )
                                                 ,error_message                   VARCHAR2(1000 )
                                                 ,process_stage                   VARCHAR2(100 )
                                                 ,header_status                   VARCHAR2(100 )
                                                 ,attribute1                      VARCHAR2 (150 ) 
                                                 ,attribute3			  VARCHAR2 (150 )
                                                 ,attribute4			  VARCHAR2 (150 )
                                                 ,attribute6			  VARCHAR2 (150 )
                                                 ,attribute7			  VARCHAR2 (150 )
                                                 ,attribute8			  VARCHAR2 (150 )
                                                 ,attribute10			  VARCHAR2 (150 )
                                                 ,attribute11 			  VARCHAR2 (150 )
                                                 ,JCPX_PO_MRCH_POCONV_STG_ID       NUMBER
                                                );
      
      TYPE t_jcpx_rcv_shpmnt_l_err_rec IS RECORD( shipment_header_id  NUMBER);
                 
	  TYPE t_jcpx_rcv_shpmnt_lines_tab IS TABLE OF SHIPMENT_LIN_STG%ROWTYPE INDEX BY BINARY_INTEGER;
      lt_jcpx_rcv_shpmnt_lns_tab      t_jcpx_rcv_shpmnt_lines_tab;
      
      TYPE t_jcpx_rcv_shpmnt_hdrs_tab IS TABLE OF JCPX_RCV_MRCH_SHP_HDR_STG%ROWTYPE INDEX BY BINARY_INTEGER;
      lt_jcpx_rcv_shpmnt_hdrs_tab      t_jcpx_rcv_shpmnt_hdrs_tab;
      
      TYPE t_jcpx_rcv_shpmnt_l_err_type IS TABLE OF t_jcpx_rcv_shpmnt_l_err_rec INDEX BY BINARY_INTEGER;
      t_jcpx_rcv_shpmnt_l_err_tab      t_jcpx_rcv_shpmnt_l_err_type;
      
	  
      CURSOR csr_validate_hdr
       IS
           SELECT *
           FROM JCPX_RCV_MRCH_SHP_HDR_STG
           WHERE UPPER(process_status) IN (UPPER(gc_new_records),UPPER(gc_import_error),UPPER(gc_validation_error) )
             AND JCPX_PO_MRCH_POCONV_STG_ID BETWEEN pv_shpmnt_hdr_from AND pv_shpmnt_hdr_to;
	  
	  CURSOR csr_validate_lns
       IS
           SELECT *
           FROM SHIPMENT_LIN_STG
           WHERE UPPER(process_status) IN (UPPER(gc_new_records),UPPER(gc_import_error),UPPER(gc_validation_error) )
             AND JCPX_PO_MRCH_POCONV_STG_ID BETWEEN pv_shpmnt_hdr_from AND pv_shpmnt_hdr_to;
      
	  
      
   BEGIN
     
       -----------------------------------
       --  getting to org id r12 setup  --
       -----------------------------------
       ln_organization_id := NULL;
       BEGIN
          SELECT ood.organization_id
            INTO ln_organization_id
            FROM apps.org_organization_definitions ood
           WHERE UPPER(ood.organization_code) = 'DMI';
          
       EXCEPTION
          WHEN NO_DATA_FOUND THEN
              
               lv_error_message             := 'Inventory Organization Not Set Up for DMI'||'.'||SQLERRM;
              
               jcpx_message_pkg.log_msg(p_msg_text => lv_error_message); 
               
               pv_errbuf  := lv_error_message;
               pn_retcode := gn_warning_retcode;
                         
          WHEN OTHERS THEN
             lv_error_message  := 'Unexpected Error for Inventory Organization id.Error :'||SQLERRM;
             
             jcpx_message_pkg.log_msg('Others Error for Inventory Organization id for DMI.Error :'||SQLERRM); 
             pv_errbuf  := lv_error_message;
             pn_retcode := gn_warning_retcode;
                                 
       END;
       
       ----------------------------------------
       --  getting to category id r12 setup  --
       ----------------------------------------
       ln_def_category_id:=NULL;
       
       BEGIN
          SELECT default_category_id
            INTO ln_def_category_id
            FROM apps.mtl_category_sets_vl 
            WHERE category_set_name = 'Inventory';
          
       EXCEPTION
          WHEN NO_DATA_FOUND THEN
               lv_error_message  := 'Inventory category set not set up';
              
               jcpx_message_pkg.log_msg('Inventory Organization Not Set Up for Inventory'||'.'||SQLERRM);
               
               pv_errbuf  := lv_error_message;
               pn_retcode := gn_warning_retcode;
                              
          WHEN OTHERS THEN
             lv_error_message  := 'Unexpected Error for Inventory category id.Error :'||SQLERRM;
             
             jcpx_message_pkg.log_msg('Others Error for Inventory Organization id for Inventory.Error :'||SQLERRM);
             pv_errbuf  := lv_error_message;
             pn_retcode := gn_warning_retcode;
                                 
       END;
       
      
     OPEN csr_validate_hdr;
     LOOP
       FETCH csr_validate_hdr
       BULK COLLECT INTO lt_jcpx_rcv_shpmnt_hdrs_tab LIMIT gn_commit_count;
      
       BEGIN
      
         ------------------------
         -- Start Validations  --
         ------------------------
         
         -------------------------
         -- Header Validations  --
         -------------------------
         FOR ln_rec_count IN lt_jcpx_rcv_shpmnt_hdrs_tab.FIRST .. lt_jcpx_rcv_shpmnt_hdrs_tab.LAST
            LOOP
            
            lv_error_message  :=  NULL;

            ------------------------------------------
            --   Purchasing period validation   --
            ------------------------------------------
            ln_period_open := NULL;
            ln_period_open := jcpx_isperiod_open_fn;
            
            IF ln_period_open = 0
            THEN
              lv_error_message := lv_error_message 
                                  || ' |Purchasing Period Not Open for the date '
                                  ||TRUNC(SYSDATE);
              lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).process_status := gc_validation_error;              
            END IF;
            
			
			----------------------------------------------
            -- Inventory Accounting period validation   --
            ----------------------------------------------
            ln_inv_acc_period_open := NULL;
            ln_inv_acc_period_open := jcpx_IsInvAccperiod_open_fn;
            
            IF ln_inv_acc_period_open = 0
            THEN
              lv_error_message := lv_error_message 
                                  || ' |Inventory Accounting period Not Open for the date '
                                  ||TRUNC(SYSDATE);
              lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).process_status := gc_validation_error; 
            END IF;
            
            ------------------------------------------
            --   Ship To Organization validation   --
            ------------------------------------------
            --jcpx_message_pkg.log_msg('Ship To Validation: ',FALSE,NULL,'LOG'); 
            IF lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ship_to_organization_id IS NOT NULL 
               THEN
               lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ship_to_organization_id_r12  := ln_organization_id;
            
                            
               IF lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ship_to_organization_id_r12 = 0
                  THEN
                  lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ship_to_organization_id_r12 := NULL;
                  lv_error_message := lv_error_message 
                                      || ' |Operating unit '
                                      ||gn_org_id
                                      ||' ship to organization DMI '
                                      ||' is not set up';
                  lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).process_status := gc_validation_error;
               END IF;
            END IF;
            
            --jcpx_message_pkg.log_msg('Vendor Validation: ',FALSE,NULL,'LOG'); 
            ---------------------------
            --   Vendor validation   --
            ---------------------------
            IF lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_name IS NOT NULL 
               AND lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_num IS NOT NULL 
               THEN
               
               lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_id_r12
                         := jcpx_isvendor_exists_fn ( lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_name
                                                     ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_num
                                                    );
                                                    
               IF lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_id_r12 = 0
                  THEN
                  lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_id_r12 := NULL;
                  lv_error_message := lv_error_message 
                                      || ' |Vendor with name '
                                      ||lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_name
                                      ||' and number '
                                      ||lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_num
                                      ||' is not set up';
                  lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).process_status := gc_validation_error;
               END IF;
            END IF;
            
            --jcpx_message_pkg.log_msg('Vendor site Validation: ',FALSE,NULL,'LOG'); 
            --------------------------------
            --   Vendor site validation   --
            --------------------------------	
			IF lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_site_code IS NOT NULL 
              AND lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_id_r12 IS NOT NULL 
               THEN
               
               lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_site_id_r12
                         := jcpx_isvendor_site_exists_fn ( lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_id_r12
                                                          ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_site_code);
                                                    
               IF lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_site_id_r12 = 0
                  THEN
                  lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_site_id_r12 := NULL;
                  lv_error_message := lv_error_message 
                                      || ' |Vendor with site code '
                                      ||lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_site_code
                                      || ' for vendor '
                                      || lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).vendor_name
                                      ||' is not set up';
                  lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).process_status := gc_validation_error;
               END IF;
            END IF;
			
            
            --jcpx_message_pkg.log_msg('Ship to Loc Validation: ',FALSE,NULL,'LOG'); */
            
            -------------------------------------
            --   Ship to Location validation   --
            -------------------------------------
            IF lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ship_to_location_code IS NOT NULL 
               THEN
               
               lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ship_to_location_id_r12
                         := jcpx_is_location_fn ( lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ship_to_location_code
                                                 ,'ship to');
                                                    
               IF lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ship_to_location_id_r12 = 0
                  THEN
                  lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ship_to_location_id_r12 := NULL;
                  lv_error_message := lv_error_message 
                                      ||' |ship to location code '
                                      ||lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ship_to_location_code
                                      ||' is not set up';
                  lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).process_status := gc_validation_error;
               END IF;
            END IF;
            
            --jcpx_message_pkg.log_msg('Employee Validation: ',FALSE,NULL,'LOG'); 
            -----------------------------
            --   Employee validation   --
            -----------------------------
            IF lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).employee_number IS NOT NULL 
               AND lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).employee_name IS NOT NULL
               THEN
               
               lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).employee_id_r12
                         := jcpx_is_employee_num_fn ( lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).employee_name
                                                     ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).employee_number);
                                                    
               IF lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).employee_id_r12 = 0
                  THEN
                  lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).employee_id_r12 := NULL;
                  lv_error_message := lv_error_message 
                                      || ' |Employee with number '
                                      ||lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).employee_number
                                      || ' and name '
                                      ||lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).employee_name
                                      ||' is not converted to r12';
                  lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).process_status := gc_validation_error;
               END IF;
            END IF;
            
            ln_term_id:=NULL;
            lv_payment_term := NULL;

            IF lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).payment_terms IS NOT NULL THEN

              
                 lv_payment_term := TRIM(lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).payment_terms); 

               ln_term_id      := jcpx_ispayment_terms_id_fn (lv_payment_term);

               IF ln_term_id = 0
               THEN
                  BEGIN

                    
                     SELECT value2
                       INTO lv_payment_term
                       FROM jcpx_glb_value_map_v
                      WHERE map_code = 'JCPX_AP_CONV_PAY_TERM'--'JCPX_AP_SUPP_PAYMENT_TERM_NAME'
                        AND value1 = lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).payment_terms
                        AND (active_end_date > SYSDATE OR active_end_date IS NULL);
                        
                     
                  EXCEPTION
                  WHEN NO_DATA_FOUND THEN

                     lv_payment_term := NULL;
                     
                    jcpx_message_pkg.log_msg('Payment Term Name missing'
                             ||lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).payment_terms||'.'||SQLERRM);

                  WHEN OTHERS THEN
                     lv_payment_term := NULL;
                    
                     lv_error_message :=
                            'Others Exception While Deriving the Payment term from Value Map '
                             ||lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).payment_terms||'.'
                             || SQLERRM;
                     jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
                     pv_errbuf  := lv_error_message;
                     pn_retcode := gn_warning_retcode;

                  END;

                  IF lv_payment_term IS NOT NULL
                  THEN

                    ln_term_id := jcpx_ispayment_terms_id_fn (lv_payment_term);

                    IF ln_term_id = 0
                    THEN
                       ln_term_id             := NULL;
                       lv_error_message := lv_error_message 
		                        || ' |Payment terms'
		                        ||lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).payment_terms
		                        ||' not valid ';
                       lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).process_status := gc_validation_error;
                    END IF;
	       
                  ELSE
                     ln_term_id             := NULL;
                     lv_error_message := lv_error_message 
		                         || ' |Payment terms'
		                         ||lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).payment_terms
		                         ||' not valid ';
                     lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).process_status := gc_validation_error;
                  END IF;
	       
               END IF;

            END IF;
           
            -------------------------------
            --   Created by validation   --
            -------------------------------
               lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).created_by
                         := gc_create_user_id ;--jcpx_isuser_exists_fn ('JCPCONV2');
                                                    
             
            ----------------------------------------
            --   Generating header interface id   --
            ----------------------------------------
            
            lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).header_interface_id := rcv_headers_interface_s.NEXTVAL;
            
            ----------------------------------------
            --   Deriving DFFs(Attributes)   --
            ----------------------------------------
			
			IF(UPPER(lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE1_11i)='CUSTOM DECORATING')
			THEN
				lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE1_R12 := 'PIC';
			ELSE
				lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE1_R12 := 'RMS';
			END IF;
			
			lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE2_R12
					:=lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE2_11I;
					
			lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE3_R12
					:='0'||lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE3_11I;
					
			lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE4_R12
					:=lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE4_11I;
					
			lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE5_R12
					:=lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE5_11I;
					
			lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE6_R12
					:=lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE6_11I;
					
			lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE7_R12
					:=lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE7_11I;
					
			lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE8_R12
					:=lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE8_11I;
					
			IF lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE9_11I IS NOT NULL
			THEN
				IF(TRIM(jcpx_global_pkg.get_subfield(lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE9_11I,2,'-'))='CMD')
				THEN
					lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE9_R12
								:=jcpx_global_pkg.get_subfield(lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE9_11I,1,'-')||'-PIC';
				ELSE
					lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE9_R12
								:=lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE9_11I;
				END IF;
			END IF;
					
			--commented for version 0.5
			--lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE10_R12
			--		:=lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE10_11I;
					
			--commented for version 0.5
			--lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE11_R12
			--		:=lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).ATTRIBUTE11_11I;
			
			
            -------------------------------
            --   Set validation status   --
            -------------------------------
            
            IF lv_error_message IS NULL THEN
               lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).process_status := gc_validation_success;
			   lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).error_message := NULL;
              
            ELSE
               lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).process_status := gc_validation_error;
               lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).error_message := lv_error_message;
               
            END IF;
            
            lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).process_stage := gc_process_stage_validation;
         END LOOP;
      EXCEPTION
         WHEN OTHERS THEN
            lv_error_text :=
                     'Unexpected error while validating Receipt header Records. '
                  || SQLERRM;
           
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            
      END;
      
      
      
         ------------------------------
         --   Update staging table   --
         ------------------------------
         BEGIN
            FORALL i IN lt_jcpx_rcv_shpmnt_hdrs_tab.FIRST .. lt_jcpx_rcv_shpmnt_hdrs_tab.LAST
               UPDATE JCPX_RCV_MRCH_SHP_HDR_STG
               SET    ou_name                      = gv_operating_unit
                     ,header_interface_id          = lt_jcpx_rcv_shpmnt_hdrs_tab(i).header_interface_id
                     ,created_by                   = lt_jcpx_rcv_shpmnt_hdrs_tab(i).created_by
                     ,org_id_r12                   = gn_org_id
                     ,ship_to_organization_id_r12  = lt_jcpx_rcv_shpmnt_hdrs_tab(i).ship_to_organization_id_r12 
                     ,vendor_id_r12                = lt_jcpx_rcv_shpmnt_hdrs_tab(i).vendor_id_r12
                     ,vendor_site_id_r12           = lt_jcpx_rcv_shpmnt_hdrs_tab(i).vendor_site_id_r12
                     ,ship_to_location_id_r12      = lt_jcpx_rcv_shpmnt_hdrs_tab(i).ship_to_location_id_r12
                     ,employee_id_r12              = lt_jcpx_rcv_shpmnt_hdrs_tab(i).employee_id_r12
                     ,payment_terms_id_r12         = ln_term_id
					 ,ATTRIBUTE1_R12			   = lt_jcpx_rcv_shpmnt_hdrs_tab(i).ATTRIBUTE1_R12
					 ,ATTRIBUTE2_R12			   = lt_jcpx_rcv_shpmnt_hdrs_tab(i).ATTRIBUTE2_R12
					 ,ATTRIBUTE3_R12			   = lt_jcpx_rcv_shpmnt_hdrs_tab(i).ATTRIBUTE3_R12
					 ,ATTRIBUTE4_R12			   = lt_jcpx_rcv_shpmnt_hdrs_tab(i).ATTRIBUTE4_R12
					 ,ATTRIBUTE5_R12			   = lt_jcpx_rcv_shpmnt_hdrs_tab(i).ATTRIBUTE5_R12
					 ,ATTRIBUTE6_R12			   = lt_jcpx_rcv_shpmnt_hdrs_tab(i).ATTRIBUTE6_R12
					 ,ATTRIBUTE7_R12			   = lt_jcpx_rcv_shpmnt_hdrs_tab(i).ATTRIBUTE7_R12
					 ,ATTRIBUTE8_R12			   = lt_jcpx_rcv_shpmnt_hdrs_tab(i).ATTRIBUTE8_R12
					 ,ATTRIBUTE9_R12			   = lt_jcpx_rcv_shpmnt_hdrs_tab(i).ATTRIBUTE9_R12
					 ,ATTRIBUTE10_R12			   = lt_jcpx_rcv_shpmnt_hdrs_tab(i).ATTRIBUTE10_R12
					 ,ATTRIBUTE11_R12			   = lt_jcpx_rcv_shpmnt_hdrs_tab(i).ATTRIBUTE11_R12
                     ,process_status               = lt_jcpx_rcv_shpmnt_hdrs_tab(i).process_status
                     ,error_message                = lt_jcpx_rcv_shpmnt_hdrs_tab(i).error_message
                     ,process_stage                = lt_jcpx_rcv_shpmnt_hdrs_tab(i).process_stage
               WHERE  shipment_header_id           = lt_jcpx_rcv_shpmnt_hdrs_tab(i).shipment_header_id;
         EXCEPTION
            WHEN OTHERS THEN
               lv_error_text :=
                      'Unexpected error while updating Receipt header staging table after validation. '
                      || SQLERRM;
             
               jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
               
         END;
         EXIT WHEN (csr_validate_hdr%NOTFOUND);
         END LOOP;           
         CLOSE csr_validate_hdr;
        
		COMMIT;
         ---------------------------
         --   Lines validations   --
         ---------------------------
         
         OPEN csr_validate_lns;
         
         LOOP
         
          FETCH csr_validate_lns
          BULK COLLECT INTO lt_jcpx_rcv_shpmnt_lns_tab LIMIT gn_commit_count;
          
      BEGIN
         FOR ln_rec_count IN lt_jcpx_rcv_shpmnt_lns_tab.FIRST .. lt_jcpx_rcv_shpmnt_lns_tab.LAST
            LOOP
            
            lv_error_message  :=  NULL;           
            
            ---------------------------------------------------------------
            --  setting error message for invalid corresponding headers  --
            ---------------------------------------------------------------
            
            --IF lt_jcpx_rcv_shpmnt_hdrs_tab(ln_rec_count).PROCESS_STATUS = gc_validation_error THEN
            --   lv_error_message := ' Header Failed Validation |';
            --END IF;
			
			ln_val_err_hdr_count := 0;
			BEGIN
			
			   SELECT count(1)
			     INTO ln_val_err_hdr_count
				 FROM JCPX_RCV_MRCH_SHP_HDR_STG
				WHERE SHIPMENT_HEADER_ID = lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).SHIPMENT_HEADER_ID
				  AND process_status = gc_validation_error;
			
			EXCEPTION
			
			   WHEN OTHERS THEN
			      ln_val_err_hdr_count := 0;
			
			END;
			
			IF ln_val_err_hdr_count <> 0 THEN
			   lv_error_message := lv_error_message 
                                  || ' Header Failed Validation |';
              lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_status := gc_validation_error;              
			END IF;

            ------------------------------------------
            --   Purchasing period validation   --
            ------------------------------------------
            ln_period_open := NULL;
            ln_period_open := jcpx_isperiod_open_fn;
            
            IF ln_period_open = 0
            THEN
              lv_error_message := lv_error_message 
                                  || ' |Purchasing Period Not Open for the date '
                                  ||TRUNC(SYSDATE);
              lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_status := gc_validation_error;              
            END IF;

			----------------------------------------------
            -- Inventory Accounting period validation   --
            ----------------------------------------------
            ln_inv_acc_period_open := NULL;
            ln_inv_acc_period_open := jcpx_IsInvAccperiod_open_fn;
            
            IF ln_inv_acc_period_open = 0
            THEN
              lv_error_message := lv_error_message 
                                  || ' |Inventory Accounting period Not Open for the date '
                                  ||TRUNC(SYSDATE);
              lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_status := gc_validation_error;
			END IF;
			
            -----------------------------------
            --   Operating unit validation   --
            -----------------------------------
            --org id
            lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).org_id_r12 := gn_org_id;
            --ou_name
            lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ou_name   := gv_operating_unit;
            
            ------------------------------------------
            --   From Organization validation   --
            ------------------------------------------
            
            IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).from_organization_id IS NOT NULL 
              AND lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).org_id_r12 IS NOT NULL 
               THEN
               lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).from_organization_id_r12 := ln_organization_id;
             
                            
               IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).from_organization_id_r12 = 0
                  THEN
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).from_organization_id_r12 := NULL;
                  lv_error_message := lv_error_message 
                                      || ' |Operating unit '
                                      ||lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).org_id_r12
                                      ||' from_organization IM '
                                      ||' is not set up ';
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_status := gc_validation_error;
               END IF;
            END IF;
            
            
            ------------------------------------------
            --   To Organization validation   --
            ------------------------------------------
            IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).to_organization_id IS NOT NULL 
            THEN
               lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).to_organization_id_r12 
                                                    := ln_organization_id;
            END IF;
            
            ---------------------------
            --   Vendor validation   --
            ---------------------------
            IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).vendor_name IS NOT NULL 
               AND lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).vendor IS NOT NULL 
               THEN
               
               lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).txn_vendor_id_r12
                         := jcpx_isvendor_exists_fn ( lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).vendor_name
                                                     ,lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).vendor
                                                    );
                                                    
               IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).txn_vendor_id_r12 = 0
                  THEN
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).txn_vendor_id_r12 := NULL;
                  lv_error_message := lv_error_message 
                                      || ' |Vendor with name '
                                      ||lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).vendor_name
                                      ||' and number '
                                      ||lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).vendor
                                      ||' is not set up';
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_status := gc_validation_error;
               END IF;
            END IF;
            
            
            --------------------------------
            --   Vendor site validation   --
            --------------------------------			
            IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).vendor_site_code IS NOT NULL 
              AND lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).txn_vendor_id_r12 IS NOT NULL 
               THEN
               
               lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).txn_vendor_site_id_r12
                         := jcpx_isvendor_site_exists_fn ( lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).txn_vendor_id_r12
                                                          ,lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).vendor_site_code);
                                                    
               IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).txn_vendor_site_id_r12 = 0
                  THEN
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).txn_vendor_site_id_r12 := NULL;
                  lv_error_message :=  lv_error_message 
                                      || ' |Vendor with site code '
                                      ||lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).vendor_site_code
                                      || ' for vendor '
                                      || lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).vendor_name
                                      ||' is not set up';
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_status := gc_validation_error;
               END IF;
            END IF; 
            
           
            -----------------------------
            --   Category validation   --
            -----------------------------
            IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).category IS NOT NULL 
               THEN
              
               lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).category_id_r12 := 
                                  jcpx_is_category_fn ( lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).category);
              
                                                    
               IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).category_id_r12 = 0
                  THEN
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).category_id_r12 := NULL;
                  lv_error_message := lv_error_message 
                                      || ' |Category '
                                      ||lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).category
                                      ||' is not set up';
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_status := gc_validation_error;
               END IF;
            END IF;
            
            
            -----------------------------
            --   Location validation   --
            -----------------------------
            IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).location_code IS NOT NULL 
               THEN
               
               lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).location_id_r12
                         := jcpx_is_location_fn ( lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).location_code
                                                 ,'Location');
                                                    
               IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).location_id_r12 = 0
                  THEN
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).location_id_r12 := NULL;
                  lv_error_message := lv_error_message 
                                      ||' |Location code '
                                      ||lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).location_code
                                      ||' is not set up';
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_status := gc_validation_error;
               END IF;
            END IF;
            
            
            ----------------------------------------
            --   Deliver to Location validation   --
            ----------------------------------------
            IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).deliverto IS NOT NULL 
               THEN
               
               lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).deliver_to_location_id_r12
                         := jcpx_is_location_fn ( lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).deliverto
                                                 ,'deliver to');
                                                    
               IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).deliver_to_location_id_r12 = 0
                  THEN
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).deliver_to_location_id_r12 := NULL;
                  lv_error_message := lv_error_message 
                                      ||' |deliver to location code '
                                      ||lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).deliverto
                                      ||' is not set up';
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_status := gc_validation_error;
               END IF;
            END IF;
            
            --jcpx_message_pkg.log_msg('Employee Validation: ',FALSE,NULL,'LOG'); 
            -----------------------------
            --   Employee validation   --
            -----------------------------
            IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).employee_number IS NOT NULL 
               AND lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).employee_name IS NOT NULL 
            THEN
               
               lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).employee_id_r12
                         := jcpx_is_employee_num_fn ( lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).employee_name
                                                     ,lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).employee_number);
                                                    
               IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).employee_id_r12 = 0
                  THEN
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).employee_id_r12 := NULL;
                  lv_error_message := lv_error_message 
                                      || ' |Employee with number '
                                      ||lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).employee_number
                                      || ' and name '
                                      ||lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).employee_name
                                      ||' is not converted to r12';
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_status := gc_validation_error;
               END IF;
            END IF;
            
            
            ----------------------
            --   Setting User   --
            ----------------------
               lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).user_id_r12 := gc_create_user_id;
            
            --jcpx_message_pkg.log_msg('PO Number Validation: ',FALSE,NULL,'LOG'); 
            ------------------------------
            --   PO number validation   --
            ------------------------------
            IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_number IS NOT NULL 
               THEN
               
               lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_header_id_r12
                         := jcpx_is_po_num_fn ( lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_number);
                                                    
               IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_header_id_r12 = 0
               THEN
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_header_id_r12 := NULL;
                  lv_error_message := lv_error_message 
                                      || ' |po number '
                                      ||lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_number
                                      ||' is not converted to r12';
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_status := gc_validation_error;
               END IF;
            END IF;
            
            --jcpx_message_pkg.log_msg('PO Validation: ',FALSE,NULL,'LOG'); 
            -----------------------
            --   PO validation   --
            -----------------------
            lv_quantity := 0;
            lv_quantity_received := 0;
            lv_quantity_billed := 0;
            
            IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_line_num IS NOT NULL
               AND lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).shipment_num IS NOT NULL
               AND lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_distribution_num IS NOT NULL
               AND lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_header_id_r12 IS NOT NULL 
               THEN
               
               jcpx_is_po_proc ( lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_line_num
                                ,lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).shipment_num
                                ,lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_distribution_num
                                ,lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_header_id_r12
                                ,lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_line_id_r12
                                ,lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).item_description
                                ,lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_line_location_id_r12
                                ,lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_distribution_id_r12
                                ,lv_quantity
                                ,lv_quantity_received
                                ,lv_quantity_billed
                                );
                                       
               IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_line_id_r12 = 0
                  AND lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_line_location_id_r12 = 0
                  AND lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_distribution_id_r12 = 0
                 
               THEN
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_line_id_r12 := NULL;
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_line_location_id_r12 := NULL;
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_distribution_id_r12 := NULL;
                     
                  lv_error_message := lv_error_message 
                                      || ' |PO with line number '
                                      ||lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_line_num
                                      ||' shipment number'
                                      ||lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).shipment_num
                                      ||'distribution num '
                                      ||lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_distribution_num
                                      ||' and header id '
                                      ||lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_header_id
                                      ||' is not converted to r12';
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_status := gc_validation_error;
               END IF;
            END IF;
            
            --jcpx_message_pkg.log_msg('Reason Validation: ',FALSE,NULL,'LOG'); 
            ---------------------------
            --   Reason validation   --
            ---------------------------
            IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).reason_name IS NOT NULL 
               THEN
               
               lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).reason_id_r12
                         := jcpx_isreason_exists_fn (lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).reason_name);
                                                    
               IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).reason_id_r12 = 0
                  THEN
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).reason_id_r12 := NULL;
                  lv_error_message := lv_error_message 
                                      || ' |reason with name '
                                      ||lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).reason_name
                                      ||' is not converted to r12';
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_status := gc_validation_error;
               END IF;
            END IF;
            
            --jcpx_message_pkg.log_msg('UOM Validation: ',FALSE,NULL,'LOG'); 
            ------------------------
            --   UOM validation   --
            ------------------------
            IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).uom IS NOT NULL 
               THEN
               
               lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).uom_r12
                         := jcpx_receipt_uom_validation_fn (lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).uom);
                                                    
               IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).uom_r12 is null
                  THEN
                  lv_error_message := lv_error_message 
                                      || ' |UOM code'
                                      ||lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).uom
                                      ||' is not converted to r12';
                  lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_status := gc_validation_error;
               END IF;
            END IF;
            
            ------------------------------------------
            --   Receipt already exist validation   --
            ------------------------------------------
            ln_receipt_count:=0;
            
            BEGIN
               SELECT count(*)
                 INTO ln_receipt_count
                 FROM rcv_transactions
                WHERE po_header_id = lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_header_id_r12
                  AND po_line_id = lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_line_id_r12
                  AND po_line_location_id = lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_line_location_id_r12
                  AND po_distribution_id = lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).po_distribution_id_r12
                  AND interface_source_line_id = lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).shipment_line_id;
               
            EXCEPTION
            
               WHEN OTHERS THEN
                  lv_error_message  := 'Unexpected Error while checking if receipt already present.Error :'||SQLERRM;
                  
                  jcpx_message_pkg.log_msg(p_msg_text => lv_error_message);
                  pv_errbuf  := lv_error_message;
                  pn_retcode := gn_warning_retcode;
                                      
            END;            
            
            IF ln_receipt_count <> 0
               THEN
               
               lv_error_message := lv_error_message 
                                   || ' |Receipt already created for this record';
               lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_status := gc_validation_error;
            END IF;
            
                      
            ---------------------------------------------
            --   Generating interface_transaction_id   --
            ---------------------------------------------
            
            lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).interface_transaction_id := rcv_transactions_interface_s.NEXTVAL;
            
			----------------------------------------
            --   Deriving header_interface_id   --
            ----------------------------------------
			BEGIN
				SELECT hstg.HEADER_INTERFACE_ID
				INTO lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).HEADER_INTERFACE_ID
				FROM JCPX_RCV_MRCH_SHP_HDR_STG hstg
				WHERE hstg.SHIPMENT_HEADER_ID = lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).SHIPMENT_HEADER_ID;
			EXCEPTION
				WHEN OTHERS THEN
				lv_error_message  := 'Unexpected Error while setting header_interface_id'||SQLERRM;
                  
                  jcpx_message_pkg.log_msg(p_msg_text => lv_error_message);
                  pv_errbuf  := lv_error_message;
                  pn_retcode := gn_warning_retcode;
			END;
			
						
			----------------------------------------
            --   Deriving DFFs(Attributes)   --
            ----------------------------------------
			
			lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE3_R12_TXN 
						:= NULL;
						
			lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE4_R12_TXN 
						:= lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE3_11I_TXN ;

			lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE7_R12_TXN 
						:= NULL;

			lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE8_R12_TXN 
						:= lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE8_11I_TXN ;
			
			--commented as not required
			--lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE9_R12_TXN 
			--			:= lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE2_11I_TXN ;

			lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE10_R12_TXN 
						:= lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE6_11I_TXN ;

						
			--addition for version 0.4 START		
			IF lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE5_11I_TXN IS NULL
				OR lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE5_11I_TXN = 'R'
			THEN
				lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE11_R12_TXN := NULL;
			ELSE
				lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE11_R12_TXN 
					:= lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE5_11I_TXN ;
			END IF;			
			--addition for version 0.4 END
					
			--commented as not required
			--lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE12_R12_TXN 
			--			:= lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE1_11I_TXN ;

			lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE13_R12_TXN 
						:= lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE11_11I_TXN ;

			lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE14_R12_TXN 
						:= lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).ATTRIBUTE4_11I_TXN ;

			
			
            -------------------------------
            --   Set validation status   --
            -------------------------------
            
            IF lv_error_message IS NULL THEN
               lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_status := gc_validation_success;
               lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).error_message := NULL;
            ELSE
               lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_status := gc_validation_error;
               lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).error_message := lv_error_message;
              
            END IF;
            
            lt_jcpx_rcv_shpmnt_lns_tab(ln_rec_count).process_stage := gc_process_stage_validation;
      END LOOP;
            
      EXCEPTION
         WHEN OTHERS THEN
            lv_error_text :=
                     'Unexpected error while validating Receipt lines Records. '
                  || SQLERRM;  
          
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
            
      END;
      
      
      
      ------------------------------
      --   Update staging table   --
      ------------------------------
      BEGIN
         FORALL i IN lt_jcpx_rcv_shpmnt_lns_tab.FIRST .. lt_jcpx_rcv_shpmnt_lns_tab.LAST
            UPDATE SHIPMENT_LIN_STG
            SET    interface_transaction_id    = lt_jcpx_rcv_shpmnt_lns_tab(i).interface_transaction_id
                  ,header_interface_id         = lt_jcpx_rcv_shpmnt_lns_tab(i).header_interface_id
                  ,uom_r12                     = lt_jcpx_rcv_shpmnt_lns_tab(i).uom_r12
                  ,org_id_r12                  = lt_jcpx_rcv_shpmnt_lns_tab(i).org_id_r12 
                  ,from_organization_id_r12    = lt_jcpx_rcv_shpmnt_lns_tab(i).from_organization_id_r12 
                  ,to_organization_id_r12      = lt_jcpx_rcv_shpmnt_lns_tab(i).to_organization_id_r12
                  ,txn_vendor_id_r12           = lt_jcpx_rcv_shpmnt_lns_tab(i).txn_vendor_id_r12 
                  ,txn_vendor_site_id_r12      = lt_jcpx_rcv_shpmnt_lns_tab(i).txn_vendor_site_id_r12 
                  ,item_id_r12                 = NULL
                  ,category_id_r12             = lt_jcpx_rcv_shpmnt_lns_tab(i).category_id_r12 
                  ,location_id_r12             = lt_jcpx_rcv_shpmnt_lns_tab(i).location_id_r12 
                  ,deliver_to_location_id_r12  = lt_jcpx_rcv_shpmnt_lns_tab(i).deliver_to_location_id_r12 
                  ,employee_id_r12             = lt_jcpx_rcv_shpmnt_lns_tab(i).employee_id_r12 
                  ,user_id_r12                 = lt_jcpx_rcv_shpmnt_lns_tab(i).user_id_r12
                  ,po_header_id_r12            = lt_jcpx_rcv_shpmnt_lns_tab(i).po_header_id_r12
                  ,po_line_id_r12              = lt_jcpx_rcv_shpmnt_lns_tab(i).po_line_id_r12
                  ,po_line_location_id_r12     = lt_jcpx_rcv_shpmnt_lns_tab(i).po_line_location_id_r12
                  ,po_distribution_id_r12      = lt_jcpx_rcv_shpmnt_lns_tab(i).po_distribution_id_r12
                  ,reason_id_r12               = lt_jcpx_rcv_shpmnt_lns_tab(i).reason_id_r12
                  ,item_description            = NULL
				  ,ATTRIBUTE1_R12_TXN          = lt_jcpx_rcv_shpmnt_lns_tab(i).ATTRIBUTE1_R12_TXN
				  ,ATTRIBUTE2_R12_TXN          = lt_jcpx_rcv_shpmnt_lns_tab(i).ATTRIBUTE2_R12_TXN
				  ,ATTRIBUTE3_R12_TXN          = lt_jcpx_rcv_shpmnt_lns_tab(i).ATTRIBUTE3_R12_TXN
			   	  ,ATTRIBUTE4_R12_TXN          = lt_jcpx_rcv_shpmnt_lns_tab(i).ATTRIBUTE4_R12_TXN
				  ,ATTRIBUTE5_R12_TXN          = lt_jcpx_rcv_shpmnt_lns_tab(i).ATTRIBUTE5_R12_TXN
				  ,ATTRIBUTE6_R12_TXN          = lt_jcpx_rcv_shpmnt_lns_tab(i).ATTRIBUTE6_R12_TXN
				  ,ATTRIBUTE7_R12_TXN          = lt_jcpx_rcv_shpmnt_lns_tab(i).ATTRIBUTE7_R12_TXN
				  ,ATTRIBUTE8_R12_TXN          = lt_jcpx_rcv_shpmnt_lns_tab(i).ATTRIBUTE8_R12_TXN
				  ,ATTRIBUTE9_R12_TXN          = lt_jcpx_rcv_shpmnt_lns_tab(i).ATTRIBUTE9_R12_TXN
				  ,ATTRIBUTE10_R12_TXN         = lt_jcpx_rcv_shpmnt_lns_tab(i).ATTRIBUTE10_R12_TXN
				  ,ATTRIBUTE11_R12_TXN         = lt_jcpx_rcv_shpmnt_lns_tab(i).ATTRIBUTE11_R12_TXN
				  ,ATTRIBUTE12_R12_TXN         = lt_jcpx_rcv_shpmnt_lns_tab(i).ATTRIBUTE12_R12_TXN
				  ,ATTRIBUTE13_R12_TXN         = lt_jcpx_rcv_shpmnt_lns_tab(i).ATTRIBUTE13_R12_TXN
				  ,ATTRIBUTE14_R12_TXN         = lt_jcpx_rcv_shpmnt_lns_tab(i).ATTRIBUTE14_R12_TXN
                  ,process_status              = lt_jcpx_rcv_shpmnt_lns_tab(i).process_status
                  ,error_message               = lt_jcpx_rcv_shpmnt_lns_tab(i).error_message
                  ,process_stage               = lt_jcpx_rcv_shpmnt_lns_tab(i).process_stage
            WHERE  shipment_header_id          = lt_jcpx_rcv_shpmnt_lns_tab(i).shipment_header_id
              AND  shipment_line_id            = lt_jcpx_rcv_shpmnt_lns_tab(i).shipment_line_id;
      EXCEPTION
         WHEN OTHERS THEN
            lv_error_text :=
                   'Unexpected error while updating Receipt lines staging table after validation. '
                   || SQLERRM;
           
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
      END;

         EXIT WHEN (csr_validate_lns%NOTFOUND);
         END LOOP;           
         CLOSE csr_validate_lns;
         
         ---------------------------------------------------------------------------------
         --   Update header staging table for validation error in corresponding lines   --
         ---------------------------------------------------------------------------------
         
         BEGIN
            SELECT DISTINCT rsl.shipment_header_id
            BULK COLLECT INTO t_jcpx_rcv_shpmnt_l_err_tab
            FROM SHIPMENT_LIN_STG rsl
            WHERE UPPER(rsl.process_status) = UPPER(gc_validation_error)
			AND JCPX_PO_MRCH_POCONV_STG_ID BETWEEN pv_shpmnt_hdr_from AND pv_shpmnt_hdr_to;--V 0.3 added this condition to remove deadlock issue
         EXCEPTION
            WHEN OTHERS THEN
               lv_error_text :=
                        'Error while Bulk Collecting Receipt lines error Records for updating corresponding header records with error status. '
                     || SQLERRM;
             
               jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);

               
         END;         
         
         BEGIN
            FORALL i IN t_jcpx_rcv_shpmnt_l_err_tab.FIRST .. t_jcpx_rcv_shpmnt_l_err_tab.LAST
               UPDATE JCPX_RCV_MRCH_SHP_HDR_STG
               SET    process_status               = gc_validation_error
                     ,error_message                = error_message||' |Corresponding line(s) failed validation'
               WHERE  shipment_header_id           = t_jcpx_rcv_shpmnt_l_err_tab(i).shipment_header_id
                 AND  process_status               = gc_validation_success;
            
         EXCEPTION
            WHEN OTHERS THEN
               lv_error_text :=
                      'Unexpected error while updating Receipt header staging table for lines error. '
                      || SQLERRM;
            
               jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            
               
         END;
         
         BEGIN
            FORALL i IN t_jcpx_rcv_shpmnt_l_err_tab.FIRST .. t_jcpx_rcv_shpmnt_l_err_tab.LAST
               UPDATE SHIPMENT_LIN_STG
               SET    process_status               = gc_validation_error
                     ,error_message                = error_message||' |One or More line(s) failed validation for this Header'
               WHERE  shipment_header_id           = t_jcpx_rcv_shpmnt_l_err_tab(i).shipment_header_id
                 AND  process_status               = gc_validation_success;
            
         EXCEPTION
            WHEN OTHERS THEN
               lv_error_text :=
                      'Unexpected error while updating Receipt header staging table for lines error. '
                      || SQLERRM;

               jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);

               
         END;
         
   EXCEPTION
      WHEN OTHERS THEN
         lv_error_text :=
                'Unexpected error while Validating Receipt data. '
                || SQLERRM;
       
         jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
       
         
         pv_errbuf  := lv_error_text;
         pn_retcode := gn_error_retcode;
         
      
   END jcpx_validate_receipt_info;
   
   
   -- +===================================================================================+
   -- | Procedure Name: jcpx_process_receipt                                              |
   -- | Description: This is the procedure which picks up all the eligible                |
   -- |              records from staging tables and the data which are marked as         |
   -- |              'Validated' are inserted into interface table and proces_status      |
   -- |              is changed to interfaced                                             |
   -- |                                                                                   |
   -- | Parameters : Type Description                                                     |
   -- |                                                                                   |
   -- | pv_shpmnt_hdr_from IN VARCHAR2                                                    |
   -- | pv_shpmnt_hdr_to   IN VARCHAR2                                                    |
   -- |                                                                                   |
   -- | Change Record:                                                                    |
   -- | ==============                                                                    |
   -- |                                                                                   |
   -- | Ver      Date           Author             Description                            |
   -- |========= ============== ================= ================                        |
   -- | 0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        |
   -- +===================================================================================+
   
   PROCEDURE jcpx_process_receipt (
                                    pv_errbuf   OUT VARCHAR2
                                   ,pn_retcode  OUT NUMBER
                                   ,pv_shpmnt_hdr_from IN VARCHAR2
                                   ,pv_shpmnt_hdr_to IN VARCHAR2
                                   )
   IS
   
      -- PL/SQL table declaration
      
      TYPE t_jcpx_rcv_shpmnt_lines_tab IS TABLE OF SHIPMENT_LIN_STG%ROWTYPE INDEX BY BINARY_INTEGER;
      lt_jcpx_rcv_shpmnt_lns_tab      t_jcpx_rcv_shpmnt_lines_tab;
      
      
      TYPE t_jcpx_rcv_shpmnt_hdrs_tab IS TABLE OF JCPX_RCV_MRCH_SHP_HDR_STG%ROWTYPE INDEX BY BINARY_INTEGER;
      lt_jcpx_rcv_shpmnt_hdrs_tab      t_jcpx_rcv_shpmnt_hdrs_tab;
      
      lv_error_text                    VARCHAR2(4000)                        := NULL;
      ln_receipt_err_count             NUMBER                                 :=0;
      ln_idx_cnt                       NUMBER                                 :=0;
      lv_error_msg                     VARCHAR2(4000)                         := NULL;
      ln_organization_id               org_organization_definitions.organization_id%TYPE;
	  ln_group_id					   NUMBER;
      
      CURSOR csr_hdr_inf
      IS
         SELECT *
         FROM JCPX_RCV_MRCH_SHP_HDR_STG
         WHERE UPPER(process_status) = UPPER(gc_validation_success)
           AND JCPX_PO_MRCH_POCONV_STG_ID BETWEEN pv_shpmnt_hdr_from AND pv_shpmnt_hdr_to
           ;
       
      CURSOR csr_lns_inf
      IS
         SELECT *
         FROM  SHIPMENT_LIN_STG
         WHERE UPPER(process_status) = UPPER(gc_validation_success)
           AND JCPX_PO_MRCH_POCONV_STG_ID BETWEEN pv_shpmnt_hdr_from AND pv_shpmnt_hdr_to
           ;
       
      
      
    BEGIN
   
	  -------------------------
	  --Deriving ln_group_id
	  -------------------------
	  --ln_group_id := RCV_INTERFACE_GROUPS_S.NEXTVAL;
      
      -- Get all the required staging table data into PL/SQL table to insert into the Interface table
      -- getting header records
      OPEN csr_hdr_inf;
      
      LOOP
         FETCH csr_hdr_inf
      BULK COLLECT INTO lt_jcpx_rcv_shpmnt_hdrs_tab LIMIT gn_commit_count;
       
      -- Inserting the records into the Interface table
      -- Inserting Header data
      BEGIN
      
         FORALL ln_count IN lt_jcpx_rcv_shpmnt_hdrs_tab.FIRST .. lt_jcpx_rcv_shpmnt_hdrs_tab.LAST SAVE EXCEPTIONS
            INSERT INTO rcv_headers_interface
               (  header_interface_id
                 ,group_id
                 ,processing_status_code
                 ,receipt_source_code
                 ,transaction_type
                 ,last_update_date
                 ,last_updated_by
                 ,creation_date
                 ,created_by
                 --,vendor_name
                 ,vendor_num
                 ,vendor_id
                 ,vendor_site_code
                 ,vendor_site_id
                 ,ship_to_organization_code
                 ,ship_to_organization_id
                 ,location_code
                 ,location_id
                 ,payment_terms_id
                 ,employee_id
                 ,org_id
                 ,operating_unit
                 ,attribute1
 	             ,attribute2  
                 ,attribute3 
				 ,attribute4
				 ,attribute5
				 ,attribute6
				 ,attribute7
				 ,attribute8
				 ,attribute9
				 ,attribute10
				 ,attribute11
               )
               VALUES
               (  lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).header_interface_id
                 ,NULL--RCV_INTERFACE_GROUPS_S.NEXTVAL
                 ,'PENDING'
                 ,'VENDOR'
                 ,'NEW'
                 ,SYSDATE
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).created_by
                 ,SYSDATE
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).created_by
                 --,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).vendor_name
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).vendor_num
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).vendor_id_r12
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).vendor_site_code
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).vendor_site_id_r12
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).ship_to_organization_code
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).ship_to_organization_id_r12
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).ship_to_location_code
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).ship_to_location_id_r12
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).payment_terms_id_r12
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).employee_id_r12
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).org_id_r12
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).ou_name
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).ATTRIBUTE1_R12
		         ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).ATTRIBUTE2_R12
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).ATTRIBUTE3_R12
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).ATTRIBUTE4_R12
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).ATTRIBUTE5_R12
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).ATTRIBUTE6_R12
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).ATTRIBUTE7_R12
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).ATTRIBUTE8_R12
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).ATTRIBUTE9_R12
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).ATTRIBUTE10_R12
                 ,lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).ATTRIBUTE11_R12
                );
         ---------------------------------
         -- Updating the stagging table --
         ---------------------------------
        FORALL ln_count IN lt_jcpx_rcv_shpmnt_hdrs_tab.FIRST .. lt_jcpx_rcv_shpmnt_hdrs_tab.LAST SAVE EXCEPTIONS
           UPDATE JCPX_RCV_MRCH_SHP_HDR_STG
              SET  process_status = gc_load_success
                  ,process_stage  = gc_process_stage_interfaced
            WHERE UPPER(process_status) = UPPER(gc_validation_success) 
              AND shipment_header_id = lt_jcpx_rcv_shpmnt_hdrs_tab(ln_count).shipment_header_id;
        
            gn_intf_rcv_h_success_cnt := gn_intf_rcv_h_success_cnt + SQL%ROWCOUNT;
           
   
    
      EXCEPTION
          WHEN OTHERS THEN
          
             ln_receipt_err_count := SQL%BULK_EXCEPTIONS.COUNT;
             gn_intf_rcv_h_fail_cnt := gn_intf_rcv_h_fail_cnt + ln_receipt_err_count;
        
             lv_error_text := 'Error while inserting the receipt headers in interface table. ' || SQLERRM;
            
                  jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
             FOR ln_err_count IN 1 .. ln_receipt_err_count
             LOOP
                lv_error_msg := NULL;
                lv_error_msg :=
                   SQLERRM (-SQL%BULK_EXCEPTIONS (ln_err_count).ERROR_CODE);
   
                ln_idx_cnt:= SQL%BULK_EXCEPTIONS (ln_err_count).ERROR_INDEX;
   
                UPDATE JCPX_RCV_MRCH_SHP_HDR_STG
                SET  process_status = gc_load_error
                    ,error_message  = lv_error_msg
                    ,process_stage  = gc_process_stage_interfaced
                WHERE shipment_header_id = lt_jcpx_rcv_shpmnt_hdrs_tab(ln_idx_cnt).shipment_header_id;
             END LOOP;
      
            
        
      END;
         EXIT WHEN (csr_hdr_inf%NOTFOUND);
      END LOOP;
      CLOSE csr_hdr_inf;
      
      -- getting lines records
      OPEN csr_lns_inf;
      
      LOOP
         FETCH csr_lns_inf
      
         BULK COLLECT INTO lt_jcpx_rcv_shpmnt_lns_tab LIMIT gn_commit_count;
         
      -- Inserting Lines data
      BEGIN
      
         FORALL ln_count IN lt_jcpx_rcv_shpmnt_lns_tab.FIRST .. lt_jcpx_rcv_shpmnt_lns_tab.LAST SAVE EXCEPTIONS
            INSERT INTO rcv_transactions_interface( interface_transaction_id
                                                   ,group_id
                                                   ,last_update_date
                                                   ,last_updated_by
                                                   ,created_by
                                                   ,request_id
                                                   ,program_application_id
                                                   ,program_id
                                                   ,program_update_date
                                                   ,processing_status_code
                                                   ,processing_request_id
                                                   ,transaction_status_code
                                                   ,category_id
                                                   ,item_id
                                                   ,employee_id
                                                   ,shipment_header_id
                                                   ,shipment_line_id
                                                   ,ship_to_location_id
                                                   ,receipt_source_code
                                                   ,vendor_id
                                                   ,vendor_site_id
                                                   ,from_organization_id
                                                   ,to_organization_id
                                                   ,po_header_id
                                                   ,po_line_id
                                                   ,po_line_location_id
                                                   ,po_distribution_id
                                                   ,destination_type_code
                                                   ,location_id 
                                                   ,deliver_to_location_id
                                                   ,reason_id
                                                   ,header_interface_id
                                                   ,project_id
                                                   ,task_id
                                                   ,org_id
                                                   ,operating_unit
                                                   --,attribute5
                                                   ,transaction_type
                                                   ,auto_transact_code                                                   
                                                   ,transaction_date
                                                   ,quantity
                                                   ,uom_code
                                                   ,source_document_code
                                                   ,processing_mode_code
                                                   ,item_description
                                                   ,creation_date
                                                   ,expected_receipt_date
                                                   ,validation_flag
                                                   ,interface_source_line_id
                                                   ,attribute1 
                                                   ,attribute2
                                                   ,attribute3
                                                   ,attribute4
                                                   ,attribute5
                                                   ,attribute6
                                                   ,attribute7
                                                   ,attribute8
                                                   ,attribute9
                                                   ,attribute10
                                                   ,attribute11
                                                   ,attribute12
                                                   ,attribute13
                                                   ,attribute14  
                                                   )
               VALUES ( lt_jcpx_rcv_shpmnt_lns_tab(ln_count).interface_transaction_id
                       ,NULL
                       ,sysdate
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).user_id_r12
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).user_id_r12
                       ,gn_request_id
                       ,gn_prog_appl_id
                       ,gn_program_id
                       ,sysdate
                       ,'PENDING'
                       ,NULL
                       ,'PENDING'
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).category_id_r12
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).item_id_r12
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).employee_id_r12
                       ,NULL
                       ,NULL
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).location_id_r12
                       ,'VENDOR'
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).txn_vendor_id_r12
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).txn_vendor_site_id_r12
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).from_organization_id_r12
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).to_organization_id_r12
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).po_header_id_r12
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).po_line_id_r12
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).po_line_location_id_r12
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).po_distribution_id_r12
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).destination_type_code
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).location_id_r12
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).location_id_r12
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).reason_id_r12
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).header_interface_id
                       ,NULL
                       ,NULL
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).org_id_r12
                       ,NULL
                       --,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).attribute5
                       ,'RECEIVE'
                       ,'DELIVER'                       
                       ,SYSDATE
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).receipt_quantity
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).uom_r12
                       ,'PO'
                       ,'BATCH'
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).item_description
                       ,sysdate
                       ,sysdate
                       ,'Y'
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).shipment_line_id
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).ATTRIBUTE1_R12_TXN
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).ATTRIBUTE2_R12_TXN
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).ATTRIBUTE3_R12_TXN
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).ATTRIBUTE4_R12_TXN
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).ATTRIBUTE5_R12_TXN
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).ATTRIBUTE6_R12_TXN
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).ATTRIBUTE7_R12_TXN
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).ATTRIBUTE8_R12_TXN
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).ATTRIBUTE9_R12_TXN
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).ATTRIBUTE10_R12_TXN
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).ATTRIBUTE11_R12_TXN
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).ATTRIBUTE12_R12_TXN
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).ATTRIBUTE13_R12_TXN
                       ,lt_jcpx_rcv_shpmnt_lns_tab(ln_count).ATTRIBUTE14_R12_TXN
                     );
         ---------------------------------
         -- Updating the stagging table --
         ---------------------------------
         FORALL ln_count IN lt_jcpx_rcv_shpmnt_lns_tab.FIRST .. lt_jcpx_rcv_shpmnt_lns_tab.LAST SAVE EXCEPTIONS
            UPDATE SHIPMENT_LIN_STG
               SET  process_status = gc_load_success
                   ,process_stage  = gc_process_stage_interfaced
             WHERE UPPER(process_status) = UPPER(gc_validation_success)
               AND shipment_line_id = lt_jcpx_rcv_shpmnt_lns_tab(ln_count).shipment_line_id;
        
         gn_intf_rcv_l_success_cnt := gn_intf_rcv_l_success_cnt + SQL%ROWCOUNT;
           
   
    
      EXCEPTION
          WHEN OTHERS THEN
          
             ln_receipt_err_count := SQL%BULK_EXCEPTIONS.COUNT;
             gn_intf_rcv_l_fail_cnt := gn_intf_rcv_l_fail_cnt + ln_receipt_err_count;
        
             lv_error_text := 'Error while inserting the receipt lines in interface table. ' || SQLERRM;
            
             jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            
   
             FOR ln_err_count IN 1 .. ln_receipt_err_count
             LOOP
                lv_error_msg := NULL;
                lv_error_msg :=
                   SQLERRM (-SQL%BULK_EXCEPTIONS (ln_err_count).ERROR_CODE);
   
                ln_idx_cnt:= SQL%BULK_EXCEPTIONS (ln_err_count).ERROR_INDEX;
   
                UPDATE SHIPMENT_LIN_STG
                SET  process_status = gc_load_error
                    ,error_message  = lv_error_msg
                    ,process_stage  = gc_process_stage_interfaced
                WHERE shipment_line_id = lt_jcpx_rcv_shpmnt_lns_tab(ln_idx_cnt).shipment_line_id;
             END LOOP;
      
      
        
      END;
         EXIT WHEN (csr_lns_inf%NOTFOUND);
      END LOOP;
      CLOSE csr_lns_inf;
     
      
   EXCEPTION
      WHEN OTHERS THEN
          
          lv_error_text :='Unexpected error while processing receipt data:  '
             || SQLERRM;
          
          jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
          pv_errbuf  := lv_error_text;
          pn_retcode := gn_error_retcode;
   
   END jcpx_process_receipt;
   
   
   -- +===================================================================================+
   -- | Procedure Name: jcpx_submit_std_prg_proc                                          |
   -- | Description: This is the procedure which submits the standard import program      |
   -- |                                                                                   |
   -- | Parameters : Type Description                                                     |
   -- |                                                                                   |
   -- |                                                                                   |
   -- | Change Record:                                                                    |
   -- | ==============                                                                    |
   -- |                                                                                   |
   -- | Ver      Date           Author             Description                            |
   -- |========= ============== ================= ================                        |
   -- | 0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        |
   -- +===================================================================================+
 PROCEDURE jcpx_submit_std_prg_proc
 IS
     lbol_request_status     BOOLEAN;
     ln_max_wait             NUMBER := 360000000000;
     lv_phase                VARCHAR2(2000);
     lv_status               VARCHAR2(2000);
     lv_dev_phase            VARCHAR2(2000);
     lv_dev_status           VARCHAR2(2000);
     lv_message              VARCHAR2(2000);
     ln_intimp_reqid         NUMBER           :=0;
     
     ln_min_header_id       NUMBER :=0;
     ln_max_header_id       NUMBER :=0;
     ln_from_header_id      NUMBER :=0;
     ln_to_header_id        NUMBER :=0;
     ln_no_of_threads       NUMBER :=0;
     ln_process_count       NUMBER :=0;
     ln_rcv_thread_rec_cnt  NUMBER :=0;
     ln_group_id            NUMBER :=0;
     ln_req_indx            NUMBER :=0;
     
     TYPE group_rec_type IS RECORD ( group_id   NUMBER) ;
     
     TYPE lt_group_id_type IS TABLE OF group_rec_type
     INDEX BY BINARY_INTEGER ;
     
     TYPE req_rec_type IS RECORD ( req_id   NUMBER) ;                                                                                                                                                                                                                                                        
     
     TYPE lt_child_req_type IS TABLE OF req_rec_type                                                                                                                                                                                                                                                         
     INDEX BY BINARY_INTEGER ;
               
               
     lt_child_req               lt_child_req_type;
     
     lt_group_id                lt_group_id_type;
    
     lv_error_fatal             VARCHAR2(50);
     lv_error_warning           VARCHAR2(50);
     ln_request_id              NUMBER;
    
     lv_error_text                VARCHAR2(4000)                        := NULL;
     ln_organization_id    org_organization_definitions.organization_id%TYPE;
 
  BEGIN
     jcpx_message_pkg.log_msg('Inside Stand proc..... : ',FALSE,NULL,'LOG'); 
     
                                 
                                   
    -----------------------------
    --Launching Import Program --
    -----------------------------
    jcpx_message_pkg.log_msg('Calling RVCTP... : ',FALSE,NULL,'LOG');                                    
                                   
    --Submit the standard Oracle Paybles import program as mentioned below:
  
     --Calculate the total number of counts for the standard program
      BEGIN 
        SELECT MIN(header_interface_id), MAX(header_interface_id), COUNT(1)
        INTO ln_min_header_id,ln_max_header_id,ln_process_count
        FROM JCPX_RCV_MRCH_SHP_HDR_STG
       WHERE process_status = gc_load_success;
      
      EXCEPTION 
         WHEN OTHERS THEN
            lv_error_text := SUBSTR('Unexpected error while getting record count for import.Error ' || SQLERRM,1,1999);
            
            jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
            
     
      END;
      
      --calculating ln_no_of_threads
      
      IF ln_process_count >10000 THEN
      
         ln_no_of_threads := ROUND(ln_process_count/10000);
      ELSE
         
         ln_no_of_threads :=1;
         
      END IF;
      
      --updating the group id for the threads
             
      ln_rcv_thread_rec_cnt :=ROUND(((ln_max_header_id - ln_min_header_id) / ln_no_of_threads));
        
      ln_from_header_id  := ln_min_header_id;
               
      ln_to_header_id    := ln_min_header_id + ln_rcv_thread_rec_cnt; --V 0.2 Updated this to set correct threading limit
        
      FOR ln_count IN 1 .. ln_no_of_threads
      LOOP          
         BEGIN
            SELECT rcv_interface_groups_s.NEXTVAL
              INTO gn_rcv_int_sequence
              FROM DUAL;
         EXCEPTION
            WHEN OTHERS
            THEN
               lv_error_text :='Unexpected Exception while deriving group id.'|| SQLERRM;

               jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
         END;
        
         BEGIN
            UPDATE rcv_headers_interface
               SET group_id = gn_rcv_int_sequence 
             WHERE header_interface_id between ln_from_header_id and ln_to_header_id
               AND UPPER(processing_status_code)='PENDING';
         EXCEPTION
            WHEN OTHERS THEN
               lv_error_text := SUBSTR('Unexpected error while updating receipr headers interface table with group id.Error ' || SQLERRM,1,1999);
               
               jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
               
         END;

         BEGIN
            UPDATE rcv_transactions_interface
               SET group_id = gn_rcv_int_sequence 
             WHERE header_interface_id between ln_from_header_id and ln_to_header_id
               AND UPPER(processing_status_code)='PENDING';
         EXCEPTION
            WHEN OTHERS THEN
               lv_error_text := SUBSTR('Unexpected error while updating receipr transactions interface table with group id.Error ' || SQLERRM,1,1999);
              
               jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
              
         END;

          
        --Storing the group id in the PL/Sql table
        lt_group_id(ln_count).group_id := gn_rcv_int_sequence;
        
        --increasing the from and to header id count
        ln_from_header_id  := ln_to_header_id + 1;
                      
        ln_to_header_id    := ln_from_header_id + ln_rcv_thread_rec_cnt;
          
     
      END LOOP; 

      FOR ln_po_process IN lt_group_id.FIRST .. lt_group_id.LAST 
      LOOP
       -----------------------------
       --Launching Import Program --
       -----------------------------
       jcpx_message_pkg.log_msg('Calling RVCTP... : ',FALSE,NULL,'LOG');                                    
                                      
      -- Calling standard import program
      ln_request_id := apps.fnd_request.submit_request ('PO'
                                                        ,'RVCTP'
                                                        ,NULL
                                                        ,SYSDATE
                                                        ,FALSE
                                                        ,'BATCH'
                                                        ,lt_group_id(ln_po_process).group_id
                                                        );
                         
                         
                         
       jcpx_message_pkg.log_msg('After RVCTP... : ',FALSE,NULL,'LOG'); 
       jcpx_message_pkg.log_msg('waiting for RVCTP... : ',FALSE,NULL,'LOG'); 
       
       COMMIT; 
       jcpx_message_pkg.log_msg('Request Submitted is ' || ln_request_id);
 
       ------------------------------------------------------------
       -- If Concurrent Program is submitted successfully, then
       -- send the concurrent request id value to calling form
       ------------------------------------------------------------
         ln_intimp_reqid:= ln_request_id;
         
         
         IF  ln_intimp_reqid  = 0 THEN
              
           lv_error_text := 'Unable to Launch Import Program for Receipts';
           gv_errbuf  := lv_error_text;
         
           jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
         
           gn_retcode := gn_warning_retcode;
                   
         ELSE
               
           lt_child_req(ln_req_indx).req_id   := ln_intimp_reqid;
           ln_req_indx := ln_req_indx + 1;
                   
         END IF; 
          
      END LOOP;
          
          --wait for all the child request.
          
      IF  lt_child_req.COUNT >0 THEN
            
      FOR ln_req_indx IN lt_child_req.FIRST .. lt_child_req.LAST
      LOOP  
    
         lv_dev_phase := NULL;
         ----------------------------------------------------------------------
         --Wait for the concurrent child requests to complete
         ----------------------------------------------------------------------
    
           
         lbol_request_status :=
            apps.fnd_concurrent.wait_for_request (request_id      => ln_request_id,
                                                  INTERVAL        => 30,
                                                  max_wait        => 100000,
                                                  phase           => lv_phase,
                                                  status          => lv_status,
                                                  dev_phase       => lv_dev_phase,
                                                  dev_status      => lv_dev_status,
                                                  MESSAGE         => lv_message
                                                 );
                            
                            
         -------------------------------------------------------------------------------------- 
         -- -Set the status of the request based on the program status of all the child request
         -------------------------------------------------------------------------------------
                   
                   
         IF UPPER(lv_dev_phase)  = 'COMPLETE' AND UPPER(lv_dev_status) = 'NORMAL' THEN
    
            jcpx_message_pkg.log_msg('Receiving Transaction Processor completed normally. Request ID - '
                                      ||TO_CHAR(lt_child_req(ln_req_indx).req_id));
            
            
         ELSIF UPPER(lv_dev_phase)  = 'COMPLETE' AND UPPER(lv_dev_status) = 'WARNING' THEN
    
            jcpx_message_pkg.log_msg('Receiving Transaction Processor completed with  warnings. Request ID - '
                                      ||TO_CHAR(lt_child_req(ln_req_indx).req_id));
            lv_error_warning:=1; 
            
            gn_retcode := gn_warning_retcode;
            
         ELSE
    
           jcpx_message_pkg.log_msg(' Receiving Transaction Processor completed with  status.'
                                    ||lv_dev_status
                                    ||' Request ID - '||TO_CHAR(lt_child_req(ln_req_indx).req_id));
           gn_retcode := gn_error_retcode; 
           
         END IF; 
    
      END LOOP;
      
      ELSE 
      
      jcpx_message_pkg.log_msg(' Receiving Transaction Processor Not submitted');
      lv_error_warning:=1;
      gn_retcode := gn_warning_retcode;
      
      END IF;
    
 EXCEPTION
    WHEN OTHERS THEN
    
       jcpx_message_pkg.log_msg('Unexpected Error in jcpx_submit_std_prg_proc.: ' 
                                 || lv_status,FALSE,NULL,'LOG');
       lv_error_text := 'Unexpected Error in jcpx_submit_std_prg_proc.  '
                           || SQLERRM;

       
       --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
       
       gv_errbuf  := lv_error_text;
       gn_retcode := gn_error_retcode;
       
  END jcpx_submit_std_prg_proc; -- End of standard Submit program
   
   -- +===================================================================================+
   -- | Procedure Name: jcpx_rcv_get_import_errors                                        |
   -- | Description: This Procedures is used to fetch the errors returned by Standard     |
   -- |              Import Program                                                       |
   -- |                                                                                   |
   -- | Parameters : Type Description                                                     |
   -- |                                                                                   |
   -- |                                                                                   |
   -- | Change Record:                                                                    |
   -- | ==============                                                                    |
   -- |                                                                                   |
   -- | Ver      Date           Author             Description                            |
   -- |========= ============== ================= ================                        |
   -- | 0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        |
   -- +===================================================================================+
     PROCEDURE jcpx_rcv_get_import_errors
       IS
        
         lv_error_text                VARCHAR2(4000)                        := NULL;
       
         
         TYPE lr_hdr_int_err_rec IS RECORD ( error_message         VARCHAR2 (2000 Byte)
                                            ,header_interface_id    NUMBER);
         TYPE lt_hdr_int_err_tab_type IS TABLE OF lr_hdr_int_err_rec
         INDEX BY BINARY_INTEGER ;
       
         TYPE lr_lns_int_err_rec IS RECORD ( error_message         VARCHAR2 (2000 Byte)
                                            ,header_interface_id    NUMBER
                                            ,interface_transaction_id    NUMBER);
         TYPE lt_lns_int_err_tab_type IS TABLE OF lr_lns_int_err_rec
         INDEX BY BINARY_INTEGER ;
         
         lt_hdr_int_err_tab      lt_hdr_int_err_tab_type;
         lt_lns_int_err_tab      lt_lns_int_err_tab_type;
         
       CURSOR csr_hdr_imp_err
       IS
         SELECT DISTINCT pia.error_message
                        ,rhi.header_interface_id
         FROM   po_interface_errors pia
               ,rcv_headers_interface rhi
               ,JCPX_RCV_MRCH_SHP_HDR_STG rsh
         WHERE  pia.interface_header_id = rhi.header_interface_id
           AND  pia.table_name = 'RCV_HEADERS_INTERFACE'
           AND  UPPER(rhi.processing_status_code) = 'ERROR'
           AND  rhi.header_interface_id = rsh.header_interface_id
           AND  pia.batch_id = rhi.group_id
           AND  pia.interface_type = 'RCV-856';
       
       CURSOR csr_lns_imp_err
       IS
         SELECT DISTINCT pia.error_message
                        ,rti.header_interface_id
                        ,rti.interface_transaction_id
         FROM   po_interface_errors pia
               ,rcv_transactions_interface rti
               ,SHIPMENT_LIN_STG rsl
         WHERE   pia.interface_line_id = rti.interface_transaction_id
           AND   UPPER(rti.processing_status_code) = 'ERROR'
           AND   pia.table_name = 'RCV_TRANSACTIONS_INTERFACE'
           AND   pia.interface_line_id = rsl.interface_transaction_id   
           AND   pia.batch_id = rti.group_id
           AND   pia.interface_type = 'RCV-856';
        
       
       
       BEGIN
         
         OPEN csr_hdr_imp_err;
         
         LOOP
          FETCH csr_hdr_imp_err
          BULK COLLECT INTO lt_hdr_int_err_tab LIMIT gn_commit_count;
          
         
         BEGIN
            FOR ln_count IN lt_hdr_int_err_tab.FIRST .. lt_hdr_int_err_tab.LAST 
               LOOP
               
               UPDATE JCPX_RCV_MRCH_SHP_HDR_STG
               SET process_status = gc_import_error,
                    error_message = lt_hdr_int_err_tab(ln_count).error_message 
               WHERE header_interface_id = lt_hdr_int_err_tab(ln_count).header_interface_id;
                 
               gn_import_rcv_h_fail_cnt :=  gn_import_rcv_h_fail_cnt + SQL%ROWCOUNT;
               
              
	    END LOOP;

         
         EXCEPTION
            WHEN OTHERS THEN
               lv_error_text :=
                      'Unexpected error while updating Receipt header staging table with import errors. '
                      || SQLERRM;
             
               jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
             
               
         END;
         EXIT WHEN (csr_hdr_imp_err%NOTFOUND);
         END LOOP;
         CLOSE csr_hdr_imp_err;
         
         OPEN csr_lns_imp_err;
         
         LOOP
          FETCH csr_lns_imp_err
          BULK COLLECT INTO lt_lns_int_err_tab LIMIT gn_commit_count;
           
         BEGIN
            FOR ln_count IN lt_lns_int_err_tab.FIRST .. lt_lns_int_err_tab.LAST 
               LOOP
               UPDATE SHIPMENT_LIN_STG
               SET  process_status = gc_import_error,
                    error_message = lt_lns_int_err_tab(ln_count).error_message 
               WHERE header_interface_id = lt_lns_int_err_tab(ln_count).header_interface_id
                 AND interface_transaction_id = lt_lns_int_err_tab(ln_count).interface_transaction_id;
               
               gn_import_rcv_l_fail_cnt := gn_import_rcv_l_fail_cnt + SQL%ROWCOUNT;
               

	    END LOOP;
               
         
         
         EXCEPTION
            WHEN OTHERS THEN
               lv_error_text :=
                      'Unexpected error while updating Receipt lines staging table with import errors. '
                      || SQLERRM;
               
               jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
              
               
         END;
         EXIT WHEN (csr_lns_imp_err%NOTFOUND);
         END LOOP;
         CLOSE csr_lns_imp_err;
         
            
         BEGIN
            SELECT rsh.error_message
                  ,rsh.header_interface_id
            BULK COLLECT INTO lt_hdr_int_err_tab
            FROM JCPX_RCV_MRCH_SHP_HDR_STG rsh
			WHERE EXISTS
					(SELECT 1 FROM
					 SHIPMENT_LIN_STG rsl
					 WHERE UPPER(rsl.process_status) = UPPER(gc_import_error)
					 AND rsl.header_interface_id = rsh.header_interface_id
					);
         EXCEPTION
            WHEN OTHERS THEN
               lv_error_text :=
                        'Error while Bulk Collecting Receipt lines error Records during import. '
                     || SQLERRM;

               jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
               --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
               
         END;         
            
           
           
         BEGIN
            SELECT rsl.error_message
                  ,rsl.HEADER_INTERFACE_ID
                  ,rsl.shipment_line_id
            BULK COLLECT INTO lt_lns_int_err_tab
            FROM SHIPMENT_LIN_STG rsl
                ,JCPX_RCV_MRCH_SHP_HDR_STG rsh
            WHERE UPPER(rsh.process_status) = UPPER(gc_import_error)
              AND rsl.HEADER_INTERFACE_ID = rsh.HEADER_INTERFACE_ID
              ;
         EXCEPTION
            WHEN OTHERS THEN
               lv_error_text :=
                        'Error while Bulk Collecting Receipt header error Records during import. '
                     || SQLERRM;
             
               jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
               --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
               
         END;         
         
         
         BEGIN
            FORALL i IN lt_hdr_int_err_tab.FIRST .. lt_hdr_int_err_tab.LAST
               UPDATE JCPX_RCV_MRCH_SHP_HDR_STG
               SET    process_status                = gc_import_error
                     ,error_message                 = error_message||' |Corresponding line(s) failed during import'
               WHERE  header_interface_id           = lt_hdr_int_err_tab(i).header_interface_id;
           
         EXCEPTION
            WHEN OTHERS THEN
               lv_error_text :=
                      'Unexpected error while updating Receipt header staging table after for lines error during import. '
                      || SQLERRM;
              
               jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
               --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
               
         END;
            
          BEGIN
             FORALL i IN lt_lns_int_err_tab.FIRST .. lt_lns_int_err_tab.LAST
                UPDATE SHIPMENT_LIN_STG
                SET    process_status               = gc_import_error
                      ,error_message                = error_message||' |Corresponding header failed during import'
                WHERE  HEADER_INTERFACE_ID          = lt_lns_int_err_tab(i).HEADER_INTERFACE_ID;
				
          EXCEPTION
             WHEN OTHERS THEN
                lv_error_text :=
                       'Unexpected error while updating Receipt lines staging table after for header error during import. '
                       || SQLERRM;
               
                jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
                --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
                
         END;         
         
         
         -- Update the imported records status in staging table   
         
         UPDATE SHIPMENT_HDR_STG
            SET process_status = gc_import_success
          WHERE process_status = gc_load_success;
                                                
            
         gn_import_rcv_h_success_cnt := gn_import_rcv_h_success_cnt + SQL%ROWCOUNT;
         
         UPDATE SHIPMENT_LIN_STG
            SET process_status = gc_import_success
          WHERE process_status = gc_load_success
            ;
            
         gn_import_rcv_l_success_cnt := gn_import_rcv_l_success_cnt + SQL%ROWCOUNT;
         
          
        COMMIT;
         
       EXCEPTION
        WHEN OTHERS THEN
           lv_error_text := 'Others Exception in Procedure jcpx_rcv_get_import_errors.  '
                                || SQLERRM;
           
          
           jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);
           --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
           gv_errbuf  := lv_error_text;
           gn_retcode := gn_error_retcode;
           
       END jcpx_rcv_get_import_errors;
  
   -- +===================================================================================+
   -- | Procedure Name: jcpx_create_audit_entries                                         |
   -- | Description: This procedure is executed to insert the audit details in the        |
   -- |              conversion process                                                   |
   -- |                                                                                   |
   -- | Parameters :   Type Description                                                   |
   -- | pv_run_mode    IN   Running Mode                                                  |
   -- | pv_description IN   Description                                                   |
   -- | pn_audit_count IN   Audit Count                                                   |
   -- |                                                                                   |
   -- |                                                                                   |
   -- | Change Record:                                                                    |
   -- | ==============                                                                    |
   -- |                                                                                   |
   -- | Ver      Date           Author             Description                            |
   -- |========= ============== ================= ================                        |
   -- | 0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        |
   -- +===================================================================================+
   
   PROCEDURE jcpx_create_audit_entries( pv_run_mode     IN VARCHAR2
                                       ,pv_description  IN VARCHAR2
                                       ,pn_audit_count  IN NUMBER
                                       )
   IS
     
      lv_error_text                VARCHAR2(4000)                        := NULL;
      gn_conc_program_name         VARCHAR2(100)                := 'JCPX_AP_MERCH_RCV_CONV';
   
   BEGIN          
      
      -- Insert the messages in Audit table

      INSERT 
        INTO apps.jcpx_glb_audit
             (audit_rec_id
             ,request_id
             ,program_name
             ,run_mode
             ,entity
             ,description
             ,count
             ,created_by
             ,creation_date
             ,last_updated_by
             ,last_update_date             
             ,last_update_login
             )
      VALUES (
              apps.jcpx_glb_audit_s01.nextval
             ,gn_request_id
             ,gn_conc_program_name
             ,pv_run_mode
             ,'Receipt' -- Entity
             ,pv_description
             ,pn_audit_count -- Count
             ,gc_create_user_id
             ,SYSDATE
             ,gc_create_user_id
             ,SYSDATE
             ,gn_login_id
             );
             
   EXCEPTION
       WHEN OTHERS THEN
        jcpx_message_pkg.log_msg('Unexpected Error in Procedure while Inserting '||
                                 'Into Audit Table for run mode:'||pv_run_mode );
        lv_error_text := 'Unexpected Error in Procedure jcpx_create_audit_entries.  '
                            || SQLERRM;
  
        
        --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);
        gv_errbuf  := lv_error_text;
        gn_retcode := gn_warning_retcode;
                        
   
   END jcpx_create_audit_entries;
   
   
   -- +===================================================================================+
   -- | Procedure Name: rcv_log_result                                                    |
   -- | Description: This procedure is calls the audit insertion procedure to log the     |
   -- |              details of conversion process                                                   |
   -- |                                                                                   |
   -- | Parameters :   Type Description                                                   |
   -- |                                                                                   |
   -- | Change Record:                                                                    |
   -- | ==============                                                                    |
   -- |                                                                                   |
   -- | Ver      Date           Author             Description                            |
   -- |========= ============== ================= ================                        |
   -- | 0.1      06-Dec-2016    Prashant Shivaji Bhapkar         Initial version                        |
   -- +===================================================================================+
   
   PROCEDURE rcv_log_result( pv_errbuf   OUT VARCHAR2
                            ,pn_retcode  OUT NUMBER
                            ,pv_run_mode IN VARCHAR2
                            )
   IS
   
       
       lv_error_text                VARCHAR2(4000)                        := NULL;
       lv_process_status   VARCHAR2(40)                          :=NULL;
       ln_po_processed     NUMBER                                :=0;
       ln_po_import_err    NUMBER                                :=0;
       lv_extract          VARCHAR2(40)                        :='EXTRACT';
       lv_validate         VARCHAR2(40)                        :='VALIDATE';
       lv_process          VARCHAR2(40)                        :='PROCESS';
       lv_import           VARCHAR2(40)                        :='IMPORT';
       
       CURSOR lcsr_process_summary 
            IS
              SELECT rpad(description, 50,' ') process_desc
                    ,lpad(count,10,' ')        process_count
               FROM apps.jcpx_glb_audit
          WHERE request_id =  gn_request_id
          ORDER BY audit_rec_id;
    
    BEGIN
     
                                  
    IF UPPER(pv_run_mode) ='EXTRACT'
      OR UPPER(pv_run_mode) ='RE-EXTRACT'THEN
        -- Audit entries for extraction
         jcpx_message_pkg.log_msg('Getting Extraction summary : ',FALSE,NULL,'LOG');                 
                                   
        -- Calling the Audit table procedure to insert the successfully
        -- extracted record count for gtemp table into the Audit table        
         jcpx_create_audit_entries
                       (
                        lv_extract     
                       ,'No of Records successfully extracted in gtemp table' 
                       ,gn_extract_rcv_g_success_cnt
                       );
   
        -- Calling the Audit table procedure to insert the failed extraction 
        -- records count for gtemp table into the Audit table                        
         jcpx_create_audit_entries
                       (
                         lv_extract     
                       ,'No of Records failed extraction in gtemp table' 
                       ,gn_extract_rcv_g_fail_cnt
                       );   
                       
        -- Calling the Audit table procedure to insert the successfully
        -- extracted record count for receipt headers staging table into the Audit table        
         jcpx_create_audit_entries
                       (
                        lv_extract     
                       ,'No of Headers Records successfully extracted in receipt headers staging' 
                       ,gn_extract_rcv_h_success_cnt
                       );
   
        -- Calling the Audit table procedure to insert the failed extraction 
        -- records count for receipt headers staging into the Audit table                        
         jcpx_create_audit_entries
                       (
                         lv_extract     
                       ,'No of Header Records failed extraction in receipt headers staging' 
                       ,gn_extract_rcv_h_fail_cnt
                       );   
                       
        -- Calling the Audit table procedure to insert the successfully
        -- extracted record count for receipt lines staging table into the Audit table        
         jcpx_create_audit_entries
                       (
                        lv_extract     
                       ,'No of Lines Records successfully extracted in receipt lines staging' 
                       ,gn_extract_rcv_l_success_cnt
                       );
   
        -- Calling the Audit table procedure to insert the failed extraction 
        -- records count for receipt lines staging into the Audit table                        
         jcpx_create_audit_entries
                       (
                         lv_extract     
                       ,'No of Lines Records failed extraction in receipt lines staging' 
                       ,gn_extract_rcv_l_fail_cnt
                       );                     
    
    
    ELSIF UPPER(pv_run_mode) = 'VALIDATE' THEN
    
         -- Audit entries for validation
         jcpx_message_pkg.log_msg('Getting Validation summary: ',FALSE,NULL,'LOG');                 
                       
        -- Calling the Audit table procedure to insert the successfully
        -- Validated header record count into the Audit table        
         jcpx_create_audit_entries
                       (
                        lv_validate     
                       ,'No of headers Records successfully validated' 
                       ,gn_validate_rcv_h_success_cnt
                       );
   
        -- Calling the Audit table procedure to insert the failed header 
        -- validation records count into the Audit table                        
         jcpx_create_audit_entries
                       (
                         lv_validate     
                       ,'No of header Records failed validation' 
                       ,gn_validate_rcv_h_fail_cnt
                       );                     
                       
                       
        -- Calling the Audit table procedure to insert the successfully
        -- Validated lines record count into the Audit table        
         jcpx_create_audit_entries
                       (
                        lv_validate     
                       ,'No of line Records successfully validated' 
                       ,gn_validate_rcv_l_success_cnt
                       );
   
        -- Calling the Audit table procedure to insert the failed lines 
        -- validation records count into the Audit table
         jcpx_create_audit_entries
                       (
                         lv_validate     
                       ,'No of line Records failed validation' 
                       ,gn_validate_rcv_l_fail_cnt
                       );                     
                       
    
    
    ELSIF UPPER(pv_run_mode) = 'PROCESS' THEN 
       --Audit for the Interfacing.
         jcpx_message_pkg.log_msg(' Process: ',FALSE,NULL,'LOG');
                                   
        -- Calling the Audit table procedure to insert the successfully
        -- interfaced header records count into the Audit table        
         jcpx_create_audit_entries
                       (
                        lv_process     
                       ,'No of headers Records successfully interfaced' 
                       ,gn_intf_rcv_h_success_cnt
                       );
   
        -- Calling the Audit table procedure to insert the failed header 
        -- interfacing records count into the Audit table                        
         jcpx_create_audit_entries
                       (
                         lv_process     
                       ,'No of header Records failed interfacing' 
                       ,gn_intf_rcv_h_fail_cnt
                       );   
                       
                       
        -- Calling the Audit table procedure to insert the successfully
        -- interfaced line records count into the Audit table        
         jcpx_create_audit_entries
                       (
                        lv_process     
                       ,'No of line Records successfully interfaced' 
                       ,gn_intf_rcv_l_success_cnt
                       );
   
        -- Calling the Audit table procedure to insert the failed line 
        -- interfacing records count into the Audit table                        
         jcpx_create_audit_entries
                       (
                         lv_process     
                       ,'No of line Records failed interfacing' 
                       ,gn_intf_rcv_l_fail_cnt
                       );                     
                       
    
    
       -- Calling the Audit table procedure to insert the successfully
        -- imported header records count into the Audit table        
         jcpx_create_audit_entries
                       (
                        lv_import
                       ,'No of Receipt header Records successfully imported' 
                       ,gn_import_rcv_h_success_cnt
                       );
   
        -- Calling the Audit table procedure to insert the failed header
        -- imported records count into the Audit table                        
         jcpx_create_audit_entries
                       (
                         lv_import
                       ,'No of Receipt header Records failed import' 
                       ,gn_import_rcv_h_fail_cnt
                       );
                       
                       
       -- Calling the Audit table procedure to insert the successfully
        -- imported line records count into the Audit table        
         jcpx_create_audit_entries
                       (
                        lv_import
                       ,'No of Receipt line Records successfully imported' 
                       ,gn_import_rcv_l_success_cnt
                       );
   
        -- Calling the Audit table procedure to insert the failed line
        -- imported records count into the Audit table                        
         jcpx_create_audit_entries
                       (
                         lv_import
                       ,'No of Receipt line Records failed import' 
                       ,gn_import_rcv_l_fail_cnt
                       );
    END IF;
                       
        jcpx_message_pkg.log_msg( p_msg_text => '___________________________________________________________________________________________________________________________'
                                    ,p_destination => 'OUTPUT'
                                    ,p_time_prefix => FALSE
                                    ,p_wrap_prefix => NULL
                                   );  
        jcpx_message_pkg.log_msg( p_msg_text => '***************************************************************************************************************************',
                                      p_destination => 'OUTPUT',
                                      p_time_prefix => FALSE,
                                      p_wrap_prefix => NULL
                                 );                           
   
    -- Calling the Global error package to log the message
        jcpx_message_pkg.log_msg( p_msg_text => ' Development Team'||SYSDATE,
                                   p_destination => 'OUTPUT',
                                   p_time_prefix => FALSE,
                                   p_wrap_prefix => NULL
                                 );   
   
   
   
    -- Calling the Global error package to log the message
        jcpx_message_pkg.log_msg( p_msg_text => '***************************************************************************************************************************',
                                  p_destination => 'OUTPUT',
                                  p_time_prefix => FALSE,
                                  p_wrap_prefix => NULL
                                );   
      -- Calling the Global error package to log the message
        jcpx_message_pkg.log_msg( p_msg_text => '******************************************* RECEIPT CONVERSION PROCESS SUMMARY ********************************************',
                                  p_destination => 'OUTPUT',
                                  p_time_prefix => FALSE,
                                  p_wrap_prefix => NULL
                                );   
      -- Calling the Global error package to log the message
        jcpx_message_pkg.log_msg( p_msg_text => '***************************************************************************************************************************',
                                   p_destination => 'OUTPUT',
                                   p_time_prefix => FALSE,
                                   p_wrap_prefix => NULL
                                 );   
        jcpx_message_pkg.log_msg( p_msg_text => '_____________________________________________________________________________________________________________________________'
                                 ,p_destination => 'OUTPUT'
                                 ,p_time_prefix => FALSE
                                 ,p_wrap_prefix => NULL
                                );                              
      
        jcpx_message_pkg.log_msg(' Number of Processed Receipt   : '||gn_import_rcv_h_success_cnt,FALSE,NULL,'LOG');   
        jcpx_message_pkg.log_msg(' Number of Import Error Receipt: '||gn_import_rcv_h_fail_cnt,FALSE,NULL,'LOG');   
      
      -- Loop is to write the Audit table message into the concurrent program output
        FOR lrec_process_summary IN lcsr_process_summary
        LOOP
        
        jcpx_message_pkg.log_msg( p_msg_text => lrec_process_summary.process_desc||
                                                lrec_process_summary.process_count,
                                  p_destination => 'OUTPUT',
                                  p_time_prefix => FALSE,
                                  p_wrap_prefix => NULL
                                );   
        
        
        END LOOP;
   
   EXCEPTION
      WHEN OTHERS THEN
          lv_error_text :=SUBSTR('Unexpected Error in Procedure LOG_RESULTS. ' || SQLERRM,1,1999);
                     
          --jcpx_error_pkg.log_system_error (p_error_text => lv_error_text);

          jcpx_message_pkg.log_msg(p_msg_text => lv_error_text);                   
          pv_errbuf  := lv_error_text;
          pn_retcode := gn_error_retcode;
          
   END rcv_log_result;
   

END RCPT_CONV_PKB;
/
SHOW ERRORS