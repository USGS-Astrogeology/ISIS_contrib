#include "Isis.h"

#include <QString>
#include <math.h>
#include <gsl/gsl_bspline.h>
#include <gsl/gsl_multifit.h>

#include "CSVReader.h"
#include "FileName.h"
#include "UserInterface.h"


using namespace std;
using namespace Isis;

void IsisMain() {
  UserInterface &ui = Application::GetUserInterface();
  CSVReader regData(FileName(ui.GetFileName("REGISTRATIONDATA")).expanded());
  
  
  
  int degree = ui.GetInteger("DEGREE");
  
  int coefficients = ui.GetInteger("COEFFICIENTS");
  
  int numBreakPoints = coefficients + 2 - degree;
  
  int goodValues = 0;
  double maxTime = 0;
  double minTime = 3000;
  for (int i = 0; i < regData.rows(); i ++) {
    CSVReader::CSVAxis row = regData.getRow(i);
    
    if (row[8].toDouble() >= .7) {
      goodValues++;
      
      if (row[2].toDouble() > maxTime || row[2].toDouble() > maxTime) {
        maxTime = row[2].toDouble();
        
        if (maxTime < row[5].toDouble()) {
          maxTime = row[5].toDouble();
        }
      }
      
      if (row[2].toDouble() < minTime || row[5].toDouble() < minTime) {
        minTime = row[2].toDouble();
        
        if (minTime > row[5].toDouble()) {
          minTime = row[5].toDouble();
        }
      }
    }
  }
  
  
  
  gsl_vector *samples, *times, *w;
  
  samples = gsl_vector_alloc(goodValues);
  times = gsl_vector_alloc(goodValues);
  w = gsl_vector_alloc(goodValues);
  
  int k = 0;
  for (int i = 0; i < regData.rows(); i ++) {
    CSVReader::CSVAxis row = regData.getRow(i);
    
    if (row[8].toDouble() >= .7) {
      double checkLineSample = row[1].toDouble();
      double checkLineTime = row[2].toDouble();

      gsl_vector_set(samples, k, checkLineSample);
      gsl_vector_set(times, k, checkLineTime);
      gsl_vector_set(w, k, 1);
      k++;
    }
  }
  
  gsl_bspline_workspace *bsplineWorkspace;
  bsplineWorkspace = gsl_bspline_alloc(degree, numBreakPoints);
  
  gsl_bspline_knots_uniform(minTime - 0.000001, maxTime + 0.000001, bsplineWorkspace); 
  
  gsl_vector *B;
  gsl_matrix *X;
  
  B = gsl_vector_alloc(coefficients);
  X = gsl_matrix_alloc(goodValues, coefficients); 
  //Fit matrix
  for (int i = 0; i < goodValues; i++) {
    double checkLineTime = gsl_vector_get(times, i);
    
    gsl_bspline_eval(checkLineTime, B, bsplineWorkspace);
    
    for (int j = 0; j < coefficients; ++j) {
      double jB = gsl_vector_get(B, j);
      gsl_matrix_set(X, i, j, jB);
    }
  }
  
  gsl_vector_free(samples);
  gsl_vector_free(times);
  gsl_vector_free(w);
  gsl_matrix_free(X);
  gsl_vector_free(B);
  
}