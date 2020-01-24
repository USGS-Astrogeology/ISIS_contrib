/**
 * @file
 * $Revision: 1.1.1.1 $
 * $Date: 2006/10/31 23:18:08 $
 *
 *   Unless noted otherwise, the portions of Isis written by the USGS are public
 *   domain. See individual third-party library and package descriptions for
 *   intellectual property information,user agreements, and related information.
 *
 *   Although Isis has been used by the USGS, no warranty, expressed or implied,
 *   is made by the USGS as to the accuracy and functioning of such software
 *   and related material nor shall the fact of distribution constitute any such
 *   warranty, and no responsibility is assumed by the USGS in connection
 *   therewith.
 *
 *   For additional information, launch
 *   $ISISROOT/doc//documents/Disclaimers/Disclaimers.html in a browser or see
 *   the Privacy &amp; Disclaimers page on the Isis website,
 *   http://isis.astrogeology.usgs.gov, and the USGS privacy and disclaimers on
 *   http://www.usgs.gov/privacy.html.
 */

#include <iostream>
#include <iomanip>
#include <sstream>
#include <math.h>
#include "FileName.h"
#include "Constants.h"
#include "IException.h"
#include "Cubic.h"

using namespace std;
namespace Isis {

  
  /**
   * This is the the overriding virtual function that provides the expansion into
   * the parabolic equation.
   * See BasisFunction for more information.
   *
   * @param vars A vector of double values to use for the expansion.
   */
  void Cubic::Expand(const std::vector<double> &vars) {

    if((int) vars.size() != Variables()) {
      std::ostringstream msg;
      msg << "Number of variables given (" << vars.size()
          << ") does not match expected (" << Variables() << ")!"
          << std::ends;
//      std::cout << msg.str << std::endl;
//      throw Isis::iException::Message("Isis::iException::Programmer",msg.str,
//        _FILEINFO_);
    }
    double t1 = vars[0];
    double t2 = vars[1];
    p_terms.clear();
    p_terms.push_back(pow(t1, 3) - pow(t2, 3));
    p_terms.push_back(pow(t1, 2) - pow(t2, 2));
    p_terms.push_back(t1 - t2);
    
//    cout << std::setprecision(14) << t1 - t2 << "," <<  std::setprecision(14) << pow(t1, 2) - pow(t2, 2) <<  "," << std::setprecision(14) << pow(t1, 3) - pow(t2, 3) << endl;
    return;
  }
} // end namespace isis

