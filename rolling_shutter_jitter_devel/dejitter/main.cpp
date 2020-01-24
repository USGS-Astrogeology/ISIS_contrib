#include "Isis.h"

#include "FileName.h"
#include "ProcessRubberSheet.h"

#include "dejitterxform.h"

using namespace std;
using namespace Isis;

void IsisMain() {
  ProcessRubberSheet p(2,2);

  // Open the input cube
  Cube *icube = p.SetInputCube("FROM");

  // Set up the transform object for mapping output (s,l) with jitter to input (s,l) without 
  UserInterface &ui = Application::GetUserInterface();

  // The line table has only the normal readout lines with time gaps where checklines were read
  FileName lineTable = ui.GetFileName("NORMALLINETABLE");
  
  // The line table has only the normal readout lines with time gaps where checklines were read
  FileName coefficients = ui.GetFileName("COEFFICIENTS");
  
  // Jitter the normal image first
  Transform *transform = new DeJitterXForm(icube->sampleCount(), icube->lineCount(), lineTable, coefficients);

  // Determine the output size
  int samples = transform->OutputSamples();
  int lines = transform->OutputLines();

  // Allocate the output file
  p.SetOutputCube("TO", samples, lines, icube->bandCount());

  // Set up the interpolator
  Interpolator *interp = new Interpolator(Interpolator::BiLinearType);
    
  p.StartProcess(*transform, *interp);
  p.EndProcess();

  delete transform;
  delete interp;
}