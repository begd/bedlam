/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is SISCweb.
 *
 * The Initial Developer of the Original Code is Alessandro Colomba.
 * Portions created by the Alessandro Colomba are Copyright (C) 2005
 * Alessandro Colomba. All Rights Reserved.
 *
 * Contributor(s):
 *   Dan Muresan
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

package siscweb.util;

import java.io.IOException;
import java.util.logging.FileHandler;
import java.util.logging.Handler;
import java.util.logging.Level;
import java.util.logging.SimpleFormatter;

public class Logger
{
    public static final java.util.logging.Logger logger =
        java.util.logging.Logger.getAnonymousLogger();

    public static void initialize()
    {
        String fileName = null;

        // tries to set the handler to a file
        try {
            fileName = Environment.getLoggingFile();

            if(fileName != null && !"".equals(fileName)) {
                int limit = Environment.getLoggingLimit();
                int count = Environment.getLoggingCount();

                Handler handler = new FileHandler(fileName, limit, count, true);
                handler.setFormatter(new SimpleFormatter());
                logger.addHandler(handler);
                logger.setUseParentHandlers(false);
            }
        }
        catch (IOException ioe) {
            if(logger.isLoggable(Level.WARNING)) {
                logger.warning("Could not open logging file : \"" +
	                fileName + "\". Using default logger.");
            }
        }

        // sets the logging level
        String level = null;

        try {
            level = Environment.getLoggingLevel();

            logger.setLevel(Level.parse(level));
        }
        catch(IllegalArgumentException iae) {
            if(logger.isLoggable(Level.WARNING)) {
                logger.warning("Did not recognize logging level : \"" + level + "\". Defaulting to level INFO.");
            }

            logger.setLevel(Level.INFO);
        }
    }
}
