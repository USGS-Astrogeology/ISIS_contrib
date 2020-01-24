#ifndef eis_dejitter_h
#define eis_dejitter_h

#include <cmath>
#include <iostream>
#include <iomanip>

#include <vector>

#include <QPair>
#include <QString>

#include "FileName.h"
#include "TextFile.h"
#include "Transform.h"

class DeJitterXForm : public Isis::Transform {
  private:
    int p_outputSamples; // Number of samples for output
    int p_outputLines;   // Number of lines for output

    std::vector<double> m_times;

    std::vector<double> m_sampleCoeffs;
    std::vector<double> m_lineCoeffs;
    
    QList< QPair<double, double > > m_offsets; // Save off the (S,L) offsets
    
    QString validTo;
    std::ofstream outputValidFile;

  public:
    // constructor
    DeJitterXForm(const double inputSamples, const double inputLines, Isis::FileName lineTbl, Isis::FileName coefficients) {

      // Set the output size to the same as the input size

      validTo = "DejitterXYOffsets.csv";
      outputValidFile.open(validTo.toLatin1().data());
      outputValidFile << "Sample offset, Line offset" << std::endl;
      // Open the line table and read it in
      std::vector<QString> lines;
      Isis::TextFile (lineTbl.expanded(), "Input", lines);

      double maxTime = 0.027114285714286;
      for (unsigned int i = 0; i < lines.size(); ++i) {
        int comma = lines[i].indexOf(",");
        m_times.push_back(lines[i].mid(comma+1).toDouble());
        //std::cout << m_lines.back() << " , "<< m_times.back() << std::endl;
        
        
        
      }
      
      std::vector<QString> coeffs;
      Isis::TextFile (coefficients.expanded(), "Input", coeffs);
      
      for (unsigned int i = 0; i < coeffs.size(); ++i) {
        int comma = coeffs[i].indexOf(",");
        std::cout << "Line coeff: " << coeffs[i].mid(0, comma).toDouble() << std::endl;
        std::cout << "Sample coeff: " << coeffs[i].mid(comma+1).toDouble() << std::endl;
        m_lineCoeffs.push_back(coeffs[i].mid(0, comma).toDouble());
        m_sampleCoeffs.push_back(coeffs[i].mid(comma+1).toDouble());
        
      }
      
      for (unsigned int k = 0; k < lines.size(); ++k) {
        QPair <double, double> XYOffset;
        double normalizedTime = ((2 * m_times[k]) / maxTime) - 1;
        
        for (unsigned int i = 0; i < m_lineCoeffs.size(); i++) {
          XYOffset.first = XYOffset.first + (m_sampleCoeffs[i] * pow(normalizedTime, m_lineCoeffs.size() - i));
          XYOffset.second =  XYOffset.second + (m_lineCoeffs[i] * pow(normalizedTime, m_lineCoeffs.size() - i));
        }
        
        m_offsets.push_back(QPair <double, double>(XYOffset.first, XYOffset.second));
        outputValidFile << std::setprecision(14) << XYOffset.first << "," << std::setprecision(14) << XYOffset.second << std::endl;
      }
        
      
      p_outputSamples = inputSamples;
      p_outputLines = inputLines;
      
      outputValidFile.close();


    }

    // destructor
    ~DeJitterXForm() {};

    // Implementations for parent's pure virtual members
    // Convert the requested output samp/line to an input samp/line
    bool Xform(double &inSample, double &inLine, const double outSample, const double outLine) {

      // We are assuming no jitter in the Z direction. So there is only an X and Y offset
      // Use the time associated with the line number to get the X,Y offset from the sum of the 

      // Find the time associated with the output line number
      // Since the output is modeling an EIS rolling shutter image with the check lines being read
      // in between the normal readout lines  

      // Return the jittered samp line
      QPair <double, double> XYOffset = m_offsets[outLine - 1];
      
      inSample = outSample - XYOffset.first;
      inLine = outLine - XYOffset.second;

        
      //std::cout << "Output " << outSample << ", " << outLine << "  Input " << inSample << ", " << inLine << "  Offsets " << XYOffset.first << ", " << XYOffset.second << std::endl;

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
};

#endif

