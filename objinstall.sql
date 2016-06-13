prompt begin to install Noradle system schema objects
whenever sqlerror continue
@@dbmshptab.sql
whenever sqlerror exit
@@psp/install.sql
@@print/install.sql
exec DBMS_UTILITY.COMPILE_SCHEMA(upper('&pspdbu'),false);
@@contexts.sql
