create or replace PACKAGE BODY PLOG_OUT_AQ AS


--*******************************************************************************
--   NAME:   PLOG_OUT_AQ (body)
--
--   Writes the log information into an advanced queue (AQ) available for 
--   external applications
--
--   Ver    Date        Autor             Comment
--   -----  ----------  ----------------  ---------------------------------------
--   1.0    16.04.2008  Bertrand Caradec  First version
--*******************************************************************************
  
  -- exception for timeout or end-of-fetch during message dequeue
  e_dequeue_timeout EXCEPTION;
  PRAGMA exception_init    (e_dequeue_timeout, -25228);  

  -- definition of private procedures
  PROCEDURE enqueue (plog_msg IN T_LOG_QUEUE);
  PROCEDURE enqueueAutonomous (plog_msg IN T_LOG_QUEUE);
  PROCEDURE dequeue_one_msg (p_log_msg OUT NOCOPY T_LOG_QUEUE);
  
  PROCEDURE log
(
    pCTX        IN       PLOGPARAM.LOG_CTX                ,  
    pID         IN       TLOG.id%TYPE                      ,
    pLDate      IN       TLOG.ldate%TYPE                   ,
    pLHSECS     IN       TLOG.lhsecs%TYPE                  ,
    pLLEVEL     IN       TLOG.llevel%TYPE                  ,
    pLSECTION   IN       TLOG.lsection%TYPE                ,
    pLUSER      IN       TLOG.luser%TYPE                   ,
    pLTEXT      IN       TLOG.LTEXT%TYPE                   ,
    pLINSTANCE  IN       TLOG.LINSTANCE%TYPE DEFAULT SYS_CONTEXT('USERENV', 'INSTANCE'),
    pLXML        IN       SYS.XMLTYPE DEFAULT NULL
) AS
--******************************************************************************
--   NAME:   log
--
--   PARAMETERS:
--
--      pCTX               log context
--      pID                ID of the log message, generated by the sequence
--      pLDate             Date of the log message (SYSTIMESTAMP)
--      pLHSECS            Number of seconds since the beginning of the epoch
--      pLSection          formated call stack
--      pLUSER             database user (SYSUSER)
--      pLTEXT             log text
--
--   Public. Insert a log message in the advanced queue.
--   According to the context configuration, the insert statement may take place
--   in an autonomous transaction (default configuration)
--
--   Ver    Date        Autor             Comment
--   -----  ----------  ---------------   --------------------------------------
--   1.0    16.04.2008  Bertrand Caradec  Initial version
--******************************************************************************
  
  l_log_msg T_LOG_QUEUE; -- log object

BEGIN
    IF pCtx.USE_LOG4J THEN
      -- create the log object
      l_log_msg := T_LOG_QUEUE(pID, pLDate, pLHSECS, pLLEVEL, pLSECTION, pLUSER, pLTEXT, pLINSTANCE);
      
      IF pCTX.USE_OUT_TRANS = FALSE THEN
        -- log object is enqueued in the calling application transaction
        enqueue(l_log_msg);                
      ELSE
        -- log object is enqueued in an autonomous transaction
        enqueueAutonomous(l_log_msg); 
      END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    raise;
END log;
  
  PROCEDURE enqueue (plog_msg IN T_LOG_QUEUE) AS
--******************************************************************************
--   NAME:   enqueue
--
--   PARAMETERS:
--
--      plog_msg   log object to enqueue
--
--   Private. Add a log object in the advanced queue
--
--   Ver    Date        Autor             Comment
--   -----  ----------  ---------------   --------------------------------------
--   1.0    16.04.2008  Bertrand Caradec  Initial version
--******************************************************************************
  
  l_enqueue_options     DBMS_AQ.enqueue_options_t;
  l_message_properties  DBMS_AQ.message_properties_t;
  l_message_handle      RAW(16);
  l_queue_name VARCHAR2(30); 
BEGIN

   l_queue_name := 'LOG_QUEUE_TOPIC';
   
   -- enqueue the log object
   DBMS_AQ.enqueue(queue_name          => l_queue_name,        
                   enqueue_options     => l_enqueue_options,     
                   message_properties  => l_message_properties,   
                   payload             => plog_msg,             
                   msgid               => l_message_handle);
END enqueue;

  PROCEDURE enqueueAutonomous (plog_msg IN T_LOG_QUEUE) AS
--******************************************************************************
--   NAME:   enqueueAutonomous
--
--   PARAMETERS:
--
--      plog_msg   log object to enqueue
--
--   Private. Add a log object to the advanced queue in a committed
--   autonomous transaction. 
--
--   Ver    Date        Autor             Comment
--   -----  ----------  ---------------   --------------------------------------
--   1.0    16.04.2008  Bertrand Caradec  Initial version
--******************************************************************************
  
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   
   -- enqueue the object in an autonomous transaction
   enqueue(plog_msg) ;
   
   COMMIT;
END enqueueAutonomous;


PROCEDURE dequeue_one_msg
(
    pID         OUT       TLOG.id%TYPE                      ,
    pLDate      OUT       TLOG.ldate%TYPE                   ,
    pLHSECS     OUT       TLOG.lhsecs%TYPE                  ,
    pLLEVEL     OUT       TLOG.llevel%TYPE                  ,
    pLSECTION   OUT       TLOG.lsection%TYPE                ,
    pLUSER      OUT       TLOG.luser%TYPE                   ,
    pLTEXT      OUT       TLOG.LTEXT%TYPE                   ,
    pLINSTANCE  OUT       TLOG.LINSTANCE%TYPE
) AS
--******************************************************************************
--   NAME:   dequeue_one_msg
--
--   PARAMETERS:
--
--      pID                ID of the log message, generated by the sequence
--      pLDate             Date of the log message (SYSTIMESTAMP)
--      pLHSECS            Number of seconds since the beginning of the epoch
--      pLSection          formated call stack
--      pLUSER             database user (SYSUSER)
--      pLTEXT             log text
--
--   Public. Consume the advanced queue of one element. If the queue is empty,
--   the parameters are set to NULL.
--
--   Ver    Date        Autor             Comment
--   -----  ----------  ---------------   --------------------------------------
--   1.0    16.04.2008  Bertrand Caradec  Initial version
--******************************************************************************
  l_dequeue_options     DBMS_AQ.dequeue_options_t;
  l_message_properties  DBMS_AQ.message_properties_t;
  l_message_handle      RAW(16);
  
  l_log_msg T_LOG_QUEUE; -- log object

BEGIN    

      dequeue_one_msg(l_log_msg);
  
      pID := l_log_msg.lID;
      pLDate := l_log_msg.lDate;
      pLHSECS := l_log_msg.lHSecs;
      pLLEVEL := l_log_msg.lLevel;
      pLSECTION := l_log_msg.lSection;
      pLUSER := l_log_msg.lUser;
      pLTEXT := l_log_msg.lText;
      pLINSTANCE := l_log_msg.lInstance;
      
END dequeue_one_msg;


PROCEDURE dequeue_one_msg (p_log_msg OUT T_LOG_QUEUE) AS
--******************************************************************************
--   NAME:   dequeue_one_msg
--
--   PARAMETERS:
--
--      p_log_msg            Log object
--
--   Public. Consume the advanced queue of one element. The log object parameter
--   is filled by the function DBMS_AQ.dequeue(). If the queue is empty, the log
--   object is null. The transaction is not committed.
--
--   Ver    Date        Autor             Comment
--   -----  ----------  ---------------   --------------------------------------
--   1.0    16.04.2008  Bertrand Caradec  Initial version
--******************************************************************************
  l_dequeue_options     DBMS_AQ.dequeue_options_t;
  l_message_properties  DBMS_AQ.message_properties_t;
  l_message_handle      RAW(16);
  

BEGIN        
    p_log_msg := NULL;
    l_dequeue_options.wait := 0.5;
    l_dequeue_options.consumer_name := 'LOG4JSUB';
    
    IF get_queue_msg_count > 0 THEN
      -- dequeue only if the queue is not empty
      BEGIN 
        DBMS_AQ.dequeue(queue_name    => 'LOG_QUEUE_TOPIC',
                  dequeue_options     => l_dequeue_options,
                  message_properties  => l_message_properties,
                  payload             => p_log_msg,
                  msgid               => l_message_handle);
      EXCEPTION
         WHEN e_dequeue_timeout THEN
            -- dequeue timeout: no message to dequeue (not raise)
            NULL;
      END;
    END IF;
      
  EXCEPTION WHEN OTHERS THEN
    RAISE;
END dequeue_one_msg;

FUNCTION get_queue_msg_count RETURN NUMBER AS
--******************************************************************************
--   NAME:   get_queue_msg_count
--
--   Public. Returns the number of messages in the queue 
--
--   Ver    Date        Autor             Comment
--   -----  ----------  ---------------   --------------------------------------
--   1.0    16.04.2008  Bertrand Caradec  Initial version
--******************************************************************************
  l_count_val NUMBER;
  
 -- CURSOR count_curs IS
  --SELECT COUNT(*)
--  FROM QTAB_LOG
  --WHERE Q_NAME = 'LOG_QUEUE';

  CURSOR count_curs IS
  SELECT COUNT(*)
  FROM QTAB_LOG_TOPIC
  WHERE Q_NAME = 'LOG_QUEUE_TOPIC';

BEGIN
    OPEN count_curs;
    FETCH count_curs INTO l_count_val; 
    CLOSE count_curs;
    
    RETURN l_count_val;
      
  EXCEPTION WHEN OTHERS THEN
    raise;
END get_queue_msg_count;

PROCEDURE purge(pMaxDate IN TIMESTAMP DEFAULT NULL) AS
--******************************************************************************
--   NAME:   purge
--
--   PARAMETERS:
--
--      pDateMax         limit date before which old log records are deleted
--    
--   Public. Dequeue log records older than the given date from the advanced queue.
--   If no date is specificated, all log messages are dequeued.
--   The function DBMS_AQ.DEQUEUE_ARRAY() is used. The transaction is not committed. 
--
--   Ver    Date        Autor             Comment
--   -----  ----------  ---------------   --------------------------------------
--   1.0    16.04.2008  Bertrand Caradec  Initial version
--******************************************************************************
  l_nr_msg_queue pls_integer;
  l_dequeue_options     DBMS_AQ.dequeue_options_t;
  l_array_message_properties DBMS_AQ.message_properties_array_t;
  l_array_msg_id             DBMS_AQ.msgid_array_t;
  l_array_payload T_ARRAY_LOG_QUEUE;
  l_cnt pls_integer := 0;
  l_counter pls_integer;
  
  BEGIN
  
  -- get the number of messages in the queue 
  l_nr_msg_queue := get_queue_msg_count;
  
  IF l_nr_msg_queue >  0 THEN
    
    IF pMaxDate IS NOT NULL THEN
      -- limit date is given: build the dequeue condition
      l_dequeue_options.deq_condition := 'tab.user_data.lDate < ' || CHR(39) || pMaxDate || CHR(39);
    END IF;

    l_dequeue_options.wait := 0.5;
    l_dequeue_options.consumer_name := 'LOG4J';
    
    -- initialize the collections
    l_array_message_properties := DBMS_AQ.message_properties_array_t();
    l_array_msg_id :=  DBMS_AQ.msgid_array_t();
    l_array_payload := T_ARRAY_LOG_QUEUE();
    
    BEGIN
      -- all messages are loaded in the array l_array_payload
      l_cnt :=  DBMS_AQ.DEQUEUE_ARRAY(queue_name    => 'LOG_QUEUE_TOPIC',
                          dequeue_options           => l_dequeue_options,
                          array_size                => l_nr_msg_queue,
                          message_properties_array  => l_array_message_properties,
                          payload_array             => l_array_payload,
                          msgid_array               => l_array_msg_id);
    EXCEPTION
      WHEN e_dequeue_timeout THEN
         -- dequeue timeout: no message to dequeue (not raise)
         NULL;
    END;
      
 END IF;
 EXCEPTION WHEN OTHERS THEN
   RAISE;
END purge;

PROCEDURE display_one_log_msg(p_log_msg IN T_LOG_QUEUE) AS
--*******************************************************************************
--   NAME:   display_one_log_msg
--
--   PARAMETERS:
--
--      p_log_msg            Log object
--
--   Public. Display the structure of a log object to the standard output.
--   Useful for test and debug.
--
--   Ver    Date        Autor             Comment
--   -----  ----------  ---------------   ----------------------------------------
--   1.0    16.04.2008  Bertrand Caradec  Initial version
--*******************************************************************************
BEGIN
  DBMS_OUTPUT.put_line ('-----------------');
  DBMS_OUTPUT.put_line ('Log Msg Id  : ' || p_log_msg.lID);
  DBMS_OUTPUT.put_line ('Date        : ' || to_char(p_log_msg.lDate, 'YYYYMMDD HH24:MI:SS'));
  DBMS_OUTPUT.put_line ('HSECs       : ' || p_log_msg.lHSecs);
  DBMS_OUTPUT.put_line ('Level       : ' || p_log_msg.lLevel);
  DBMS_OUTPUT.put_line ('Section     : ' || p_log_msg.lSection);  
  DBMS_OUTPUT.put_line ('User        : ' || p_log_msg.lUser);
  DBMS_OUTPUT.put_line ('Text        : ' || p_log_msg.lText);
  DBMS_OUTPUT.put_line ('Instance    : ' || p_log_msg.lInstance);
END;


-- end of the package
END;
/

