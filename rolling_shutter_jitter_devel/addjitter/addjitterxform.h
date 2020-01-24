#ifndef eis_jitter_h
#define eis_jitter_h

#include <cmath>
#include <iostream>
#include <fstream>

#include <vector>

#include <QList>
#include <QPair>
#include <QString>

#include "FileName.h"
#include "HarmonicSolver.h"
#include "TextFile.h"
#include "Transform.h"

class AddJitterXForm : public Isis::Transform {
  private:
    int p_outputSamples; // Number of samples for output
    int p_outputLines;   // Number of lines for output
    bool p_checkLine; // True if this xform is doing check lines instead of the normal lines
    QList< QPair<double, double > > m_offsets; // Save off the (S,L) offsets

    std::vector<int> m_lines;
    std::vector<double> m_times;

    Isis::HarmonicSolver *m_harmonics;
    
    QString validTo;
    std::ofstream outputValidFile;

  public:
    // constructor
    // When inputLines = 0 use the line number from the table instead of what was passed in. 
    AddJitterXForm(const double inputSamples, const double inputLines, Isis::FileName lineTbl, Isis::FileName jitterHarmonics) {

      // Are we doing a noremal full image or a check line image
      // This should be an additional parameeter on the constructor, but inputLines=0 works for now
      if (inputLines == 0) {
        p_checkLine = true;
        validTo = "XYOffsetsCheckCube.csv";
        outputValidFile.open(validTo.toLatin1().data());
      }
      else {
        p_checkLine = false;
        validTo = "XYOffsetsNormCube.csv";
        outputValidFile.open(validTo.toLatin1().data());
        
      }

      // Setup the Jitter Harmonics from the harmonics csv file
      m_harmonics = new Isis::HarmonicSolver(jitterHarmonics.expanded());

      // Open the line table and read it in
      std::vector<QString> lines;
      Isis::TextFile (lineTbl.expanded(), "Input", lines);
      
      
      

      for (unsigned int i = 0; i < lines.size(); ++i) {
        int comma = lines[i].indexOf(",");
        m_lines.push_back(lines[i].mid(0, comma).toInt());
        m_times.push_back(lines[i].mid(comma+1).toDouble());
        //std::cout << m_lines.back() << " , "<< m_times.back() << std::endl;

        // As each lines is read calc and save off the jitter associated with the time of the line
        QPair <double, double> XYOffset = m_harmonics->solveXYJitter(m_times.back());

      //  std::cout << std::setprecision(14) << XYOffset.first << ", " << std::setprecision(14) << XYOffset.second << ", " << std::setprecision(7) << m_times.back() << std::endl;

        m_offsets.push_back(QPair <double, double>(XYOffset.first, XYOffset.second));
        

          outputValidFile << std::setprecision(14) << XYOffset.first << "," << std::setprecision(14) << XYOffset.second << std::endl;

      }
     
      //std::cout << "Number of offsets = " << m_offsets.size() << std::endl;

      // Save off the output image size     
      p_outputSamples = inputSamples;
      p_outputLines = m_lines.size();

      delete m_harmonics;
      

      outputValidFile.close();


    }


    // destructor
    ~AddJitterXForm() {};


    // Implementations for parent's pure virtual members
    // Convert the requested output samp/line to an input samp/line
    bool Xform(double &inSample, double &inLine, const double outSample, const double outLine) {

      // We are assuming no jitter in the Z direction. So there is only an X and Y offset
      // Use the time associated with the line number to get the X,Y offset from the sum of the 

      // Find the time associated with the output line number
      // Since the output is modeling an EIS rolling shutter image with the check lines being read
      // in between the normal readout lines  

      // Return the jittered samp line
    //  QPair <double, double> XYOffset = m_harmonics->solveXYJitter(m_times[outLine-1]);

      QPair <double, double> XYOffset = m_offsets[outLine-1];

      inSample = outSample + XYOffset.first;

      if (p_checkLine) {
        inLine = m_lines[outLine-1] + XYOffset.second;
        
      }
      else {
        inLine = outLine + XYOffset.second;
      }

       

      return true;
    }


    // Return the output number of samples
    int OutputSamples() const {
      return p_outputSamples;
    }

    // Return the output number of lines
    int OutputLines() const {
      return p_outputLines;
    }

    // Return the (s.l) offset pairs that have been saved
    QList< QPair <double,double > > allOffsets() {
      return m_offsets;
    }

};

#endif

