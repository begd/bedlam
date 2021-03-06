@echo off
rem This is a batch file for starting the simple GUI console. Currently,this
rem script must be run from the server directory containing the
rem server.properties file.  See http://alicebot.org for more information.
rem
rem ==========================================================================
rem Alicebot Program D
rem Copyright (C) 1995-2001, A.L.I.C.E. AI Foundation
rem 
rem This program is free software; you can redistribute it and/or
rem modify it under the terms of the GNU General Public License
rem as published by the Free Software Foundation; either version 2
rem of the License, or (at your option) any later version.
rem
rem You should have received a copy of the GNU General Public License
rem along with this program; if not, write to the Free Software
rem Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, 
rem USA.
rem ==========================================================================

set ALICE_HOME=.
set SERVLET_LIB=lib/servlet.jar
set ALICE_LIB=lib/aliceserver.jar
set JS_LIB=lib/js.jar

rem Set SQL_LIB to the location of your database driver.
set SQL_LIB=lib/mysql_comp.jar

rem These are for Jetty; you will want to change these if you are using a different http server.
set HTTP_SERVER_LIBS=lib/org.mortbay.jetty.jar

set PROGRAMD_CLASSPATH=%SERVLET_LIB%;%ALICE_LIB%;%JS_LIB%;%SQL_LIB%;%HTTP_SERVER_LIBS%

start javaw -classpath %PROGRAMD_CLASSPATH% org.alicebot.gui.SimpleConsole %1
