/**
 * @file
 * $Revision: 1.5 $
 * $Date: 2010/04/09 21:11:43 $
 *
 *   Unless noted otherwise, the portions of Isis written by the USGS are
 *   public domain. See individual third-party library and package descriptions
 *   for intellectual property information, user agreements, and related
 *   information.
 *
 *   Although Isis has been used by the USGS, no warranty, expressed or
 *   implied, is made by the USGS as to the accuracy and functioning of such
 *   software and related material nor shall the fact of distribution
 *   constitute any such warranty, and no responsibility is assumed by the
 *   USGS in connection therewith.
 *
 *   For additional information, launch
 *   $ISISROOT/doc//documents/Disclaimers/Disclaimers.html
 *   in a browser or see the Privacy &amp; Disclaimers page on the Isis website,
 *   http://isis.astrogeology.usgs.gov, and the USGS privacy and disclaimers on
 *   http://www.usgs.gov/privacy.html.
 */
#include <math.h>
#include <stdio.h>
#include <sstream>

#include <QPair>
#include <QString>

#include "Constants.h"
#include "CSVReader.h"
#include "HarmonicSolver.h"
#include "IException.h"

using namespace std;

namespace Isis {
  
  HarmonicSolver::HarmonicSolver(const QString &file) {
    
    m_file.read(file);
    
  }
  
  QPair <double, double> HarmonicSolver::solveXYJitter(const double time) {
    
    //x is sample and y is line
    double x_jitter = 0.0;
    double y_jitter = 0.0;
    
    for (int i = 0; i < m_file.rows(); i++) {
      CSVReader::CSVAxis row = m_file.getRow(i);
      
      double frequency = row[0].toDouble() * TWOPI;
      
      double x_amp = row[1].toDouble();
      double x_phase = row[2].toDouble();
      
      double y_amp = row[3].toDouble();
      double y_phase = row[4].toDouble();
      
      double x_result = (x_amp * cos(frequency*time - x_phase));  
      double y_result = (y_amp * cos(frequency*time - y_phase));
      
      x_jitter = x_jitter + x_result;
      y_jitter = y_jitter + y_result;
    }

    return QPair <double, double>(x_jitter, y_jitter);
    
  }

}
