#include "Isis.h"

#include <QPair>
#include <QString>

#include "AutoReg.h"
#include "AutoRegFactory.h"
#include "Chip.h"
#include "Cube.h"
#include "CSVReader.h"
#include "FileName.h"
#include "HarmonicSolver.h"
#include "UserInterface.h"



using namespace std;
using namespace Isis;

void IsisMain() {
  UserInterface &ui = Application::GetUserInterface();
  
  Cube jitterCube;
  jitterCube.open(ui.GetFileName("JITTEREDCUBE"), "r");
  
  Cube checkCube;
  checkCube.open(ui.GetFileName("CHECKCUBE"), "r");
  
  CSVReader checkLinesTable(FileName(ui.GetFileName("CHECKLINETABLE")).expanded());
  
  CSVReader normTable(FileName(ui.GetFileName("NORMALLINETABLE")).expanded());
  
  double scale = ui.GetDouble("SCALE");
  
  Pvl defFile;
  defFile.read(ui.GetFileName("DEFFILE"));
  AutoReg *ar = AutoRegFactory::Create(defFile);
  
  int pointSpacing = jitterCube.sampleCount();
  
  ofstream outputFile;
  QString to(FileName(ui.GetFileName("TO")).expanded());
  outputFile.open(to.toLatin1().data());
  outputFile << "# checkline line, checkline sample, checkline time taken, matched jittered image line, matched jittered image sample, matched jittered image time taken, delta line, delta sample, goodness of fit, registration success \n";

  ofstream regStatsFile;
  regStatsFile.open("RegistrationStats.txt");
//   ofstream outputValidFile;
//   QString validTo("ValidRegistration.csv");
//   outputValidFile.open(validTo.toLatin1().data());
  
  for (int k = 0; k < checkCube.lineCount(); k++) {

    CSVReader::CSVAxis checkLineRow = checkLinesTable.getRow(k);
    if (checkLineRow.dim() == 0) break;
    CSVReader::CSVAxis normRow = normTable.getRow(checkLineRow[0].toInt() - 1);

    int sample = (int)(pointSpacing/2.0 + 0.5);
    
    ar->PatternChip()->TackCube(sample, k + 1); 
    ar->PatternChip()->Load(checkCube);
    
    ar->SearchChip()->TackCube(sample, checkLineRow[0].toInt() * scale); //The checkline will correspond to the line number that the checkCube was taken at
    ar->SearchChip()->Load(jitterCube);
    
    ar->Register();
    
    //Get the fit chip at the 34th line
    if (k == 1) {
      Chip *fitChip = ar->FitChip();
      fitChip->Write("fitChip.cub");
    }
    
//     if (ar->Success()) {
//       outputValidFile << checkLineRow[0].toInt() << "," << sample << "," << std::setprecision(14) << checkLineRow[1].toDouble() << "," << ar->CubeLine() << "," << ar->CubeSample() << ","  << normRow[1] << "," << checkLineRow[0].toInt() - ar->CubeLine() << "," << sample - ar->CubeSample() << "," << ar->GoodnessOfFit() << "\n";
//     }

    outputFile << checkLineRow[0].toInt() << "," << sample/scale << "," << std::setprecision(14) << checkLineRow[1].toDouble() << "," << ar->CubeLine()/scale << "," << ar->CubeSample()/scale << ","  << normRow[1] << "," << checkLineRow[0].toInt() - ar->CubeLine()/scale << "," << sample/scale - ar->CubeSample()/scale << "," << ar->GoodnessOfFit() << "," << ar->Success() << "\n";

  }
  Pvl regStats = ar->RegistrationStatistics();
  regStatsFile << regStats << endl;
  regStatsFile << endl;
  regStatsFile.close();
  outputFile.close();
//   outputValidFile.close();

}
