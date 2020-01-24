#include "Isis.h"

#include <QString>

#include "LeastSquares.h"
#include "NthOrderPolynomial.h"
#include "BasisFunction.h"
#include "CSVReader.h"
#include "FileName.h"

#include "UserInterface.h"



using namespace std;
using namespace Isis;

void IsisMain() {
  UserInterface &ui = Application::GetUserInterface();
  
  CSVReader checkLinesTable(FileName(ui.GetFileName("REGISTRATIONDATA")).expanded());
  
  double tolerance = ui.GetDouble("TOLERANCE");
  
  int degree = ui.GetInteger("DEGREE");
  
  double maxTime = ui.GetDouble("MAXTIME");
  
  BasisFunction *lineFunction = new NthOrderPolynomial(degree);
  BasisFunction *sampleFunction = new NthOrderPolynomial(degree);
  
  LeastSquares lsqLine(*lineFunction, false, false, false, false);
  LeastSquares lsqSample(*sampleFunction, false, false, false, false);
  
  std::vector<double> known(2);
  
  for (int i = 0; i < checkLinesTable.rows(); i++) {
    CSVReader::CSVAxis checkLineRow = checkLinesTable.getRow(i);
    
    if (checkLineRow[8].toDouble() >= tolerance) {
      
      /*Normalization Equation
       * 
       * a = min of scale 
       * b = max of scale
       * 
       * ((b - a)(x - min(x)) / (max(x) - min(x))) + a 
       * 
       * We're normalizing from -1 to 1 so the equation below is simplified
       */
      
      known[0] = ((2 * checkLineRow[5].toDouble()) / maxTime) - 1;
      known[1] = ((2 * checkLineRow[2].toDouble()) / maxTime) - 1;
      
      lsqLine.AddKnown(known, checkLineRow[6].toDouble());
      lsqSample.AddKnown(known, checkLineRow[7].toDouble());
    }
  }
  
  lsqLine.Solve();
  lsqSample.Solve();
  
  
  ofstream outputCoefficientFile;
  QString coefficientTo(FileName(ui.GetFileName("COEFFICIENTTO")).expanded());
  outputCoefficientFile.open(coefficientTo.toLatin1().data());
  outputCoefficientFile << "# Line, Sample" << endl;
  
  for (int i = 0; i < degree; i++) {
    outputCoefficientFile << std::setprecision(14) << lineFunction->Coefficient(i) << "," << std::setprecision(14) << sampleFunction->Coefficient(i) << endl;
  }
  
  
  ofstream outputResidualFile;
  QString residualTo(FileName(ui.GetFileName("RESIDUALTO")).expanded());
  outputResidualFile.open(residualTo.toLatin1().data());  
  
  outputResidualFile << "# Registered Line, Solved Line, Registered Line Residual, Registered Sample, Solved Sample, Sample Residual, Time Taken" << endl;
  
  for (unsigned int i = 0; i < lsqLine.Residuals().size(); i++) {
    CSVReader::CSVAxis checkLineRow = checkLinesTable.getRow(i);
    
    double solvedLine = 0;
    double solvedSample = 0;
    
    for (int k = 0; k < degree; k++) {
      solvedLine = solvedLine + lineFunction->Coefficient(k) * pow(checkLineRow[5].toDouble(), k+1);
      solvedSample = solvedSample + sampleFunction->Coefficient(k) * pow(checkLineRow[5].toDouble(), k+1);
    }
    
    outputResidualFile << std::setprecision(14) << checkLineRow[3].toDouble() << "," << std::setprecision(14) << checkLineRow[0].toDouble() - solvedLine << "," << std::setprecision(14) << lsqLine.Residual(i) << "," << std::setprecision(14) << checkLineRow[4].toDouble() << "," << std::setprecision(14) << checkLineRow[1].toDouble() - solvedSample << "," << std::setprecision(14) << lsqSample.Residual(i) << "," << std::setprecision(14) << checkLineRow[5].toDouble() << endl;
  }
  
  delete lineFunction;
  delete sampleFunction;
  
  outputResidualFile.close();
  outputCoefficientFile.close();
}