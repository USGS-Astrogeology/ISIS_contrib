#include "Isis.h"


#include "FileName.h"

#include <iomanip>


using namespace std;
using namespace Isis;

void IsisMain() {
    UserInterface &ui = Application::GetUserInterface();
    int totalLines = ui.GetInteger("NLINES");
    int checkLineCount = ui.GetInteger("CHECKLINECOUNT");
    int uniqueChecklinesCount = ui.GetInteger("UNIQUECHECKLINES");
    
    if (totalLines == 0) {
      cout << "Error: Number of lines must be greater than 0." << endl;
      return;
    } 
    
    if ( uniqueChecklinesCount > checkLineCount ) {
      cout << "Error: Number of unique checklines must be less than or equal to the number of checklines." << endl;
      return;
    } 
    
    QString to(FileName(ui.GetFileName("TO")).expanded());
    ofstream outputWholeFile;
    outputWholeFile.open(to.toLatin1().data());
    
    QString path(FileName(ui.GetFileName("TO")).originalPath());
    QString name(FileName(ui.GetFileName("TO")).baseName());
    QString extension(FileName(ui.GetFileName("TO")).extension());    
    
    QString normalTo = path + "/" + name + "_normal." + extension;
    ofstream outputNormalFile;
    outputNormalFile.open(normalTo.toLatin1().data());
    
    QString checkLineTo;
    ofstream outputCheckLineFile;

      checkLineTo = path + "/" + name + "_shadow." + extension;

    
    outputCheckLineFile.open(checkLineTo.toLatin1().data());

    double time = ui.GetDouble("EXPOSURETIME");
    
    double timePerLine = time / totalLines;
    
    double checkLineFrequency = totalLines/checkLineCount;

    //Number of lines between each checkline in the image
    double uniqueChecklinesSpacing = 1 + totalLines/(uniqueChecklinesCount + 1);

    
    //Vector to store the unique checkline numbers
    vector<int> uniqueChecklines;
    for (int i = 1; i <= uniqueChecklinesCount; i++) {
      uniqueChecklines.push_back(i * (int)uniqueChecklinesSpacing);
    }
    
    int checkLineCountdown = 0;
    int uniqueCheckLineIndex = 0;
    int checkLinesWritten = 0;
    
    outputWholeFile << uniqueChecklines[uniqueCheckLineIndex] << "," << std::setprecision(14) << (timePerLine - timePerLine/2) << "\n";
    outputCheckLineFile << uniqueChecklines[uniqueCheckLineIndex] << "," << std::setprecision(14) << (timePerLine - timePerLine/2) << "\n";
    
    uniqueCheckLineIndex++;
    checkLinesWritten++;

    checkLineCountdown = (int)checkLineFrequency + (int)(checkLineFrequency/checkLineCount + 0.5);
    
    for (int k = 1; k <= totalLines; k++) {
      outputWholeFile << k << "," << std::setprecision(14) << (((k + checkLinesWritten) * timePerLine) - (timePerLine/2)) << "\n";
      outputNormalFile << k << "," << std::setprecision(14) << (((k + checkLinesWritten) * timePerLine) - (timePerLine/2)) << "\n";
      checkLineCountdown--;
      
      if (checkLineCountdown <= 0 && checkLinesWritten <= checkLineCount) {
        if (checkLinesWritten == checkLineCount - 1 ) {}
        else {
          checkLinesWritten++;
          outputWholeFile << uniqueChecklines[uniqueCheckLineIndex] << "," << std::setprecision(14) << (((k + checkLinesWritten) * timePerLine) - (timePerLine/2)) << "\n";
          outputCheckLineFile << uniqueChecklines[uniqueCheckLineIndex] << "," << std::setprecision(14) << (((k + checkLinesWritten) * timePerLine) - (timePerLine/2)) << "\n";

          if ( uniqueCheckLineIndex >= 2) {
            uniqueCheckLineIndex = 0;
          }
          else {
            uniqueCheckLineIndex++;
          }
          
          
          checkLineCountdown = (int)checkLineFrequency + (int)(checkLineFrequency/checkLineCount + 0.5);
        }
      }
    }
    checkLinesWritten++;
    outputWholeFile << uniqueChecklines[uniqueCheckLineIndex] << "," << std::setprecision(14) << (((totalLines + checkLinesWritten) * timePerLine) - (timePerLine/2)) << "\n";
    outputCheckLineFile << uniqueChecklines[uniqueCheckLineIndex] << "," << std::setprecision(14) << (((totalLines + checkLinesWritten) * timePerLine) - (timePerLine/2)) << "\n";

    outputWholeFile.close();
    outputNormalFile.close();
    outputCheckLineFile.close();
}
