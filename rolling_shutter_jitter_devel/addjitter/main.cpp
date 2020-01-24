#include "Isis.h"

#include "QDebug"

#include "FileName.h"
#include "ProcessRubberSheet.h"

#include "addjitterxform.h"

using namespace std;
using namespace Isis;

void IsisMain() {
  ProcessRubberSheet p(2,2);

  // Open the input cube
  Cube *icube = p.SetInputCube("FROM");

  // Set up the transform object for mapping output (s,l) with jitter to input (s,l) without
  UserInterface &ui = Application::GetUserInterface();

  // The line table has only the normal readout lines with time gaps where checklines were read
  FileName lineTable = ui.GetFileName("NormalLineTable");
  FileName checkLineTable = ui.GetFileName("CheckLineTable");
  FileName jitterHarmonics = ui.GetFileName("JITTERSOURCE");
  
  //X is sample and Y is line
  Transform *transform = new AddJitterXForm(icube->sampleCount(), icube->lineCount(), lineTable, jitterHarmonics);

  // Determine the output size
  int samples = transform->OutputSamples();
  int lines = transform->OutputLines();

  // Allocate the output file
  p.SetOutputCube("NORMALTO", samples, lines, icube->bandCount());

  // Set up the interpolator
  Interpolator *interp;
  if (ui.GetString("INTERPOLATION") == "BILINEAR") {
    interp = new Interpolator(Interpolator::BiLinearType);
  }
  else {
    interp = new Interpolator(Interpolator::CubicConvolutionType);
  }

  p.StartProcess(*transform, *interp);
  p.EndProcess();


  //std::cout << "Offsets" << std::endl;
  //QList< QPair<double, double > > offsets = ((AddJitterXForm*)transform)->allOffsets();
  //for (int i = 0; i < offsets.size(); i++) {
  //    std::cout << offsets[i].first << ", " << offsets[i].second << std::endl;
  delete transform;
  delete interp;
  
  icube = p.SetInputCube("FROM");
  // Jitter the shadow checklines
  transform = new AddJitterXForm(icube->sampleCount(), 0, checkLineTable, jitterHarmonics);

  // Determine the output size
  samples = transform->OutputSamples();
  lines = transform->OutputLines();

  // Allocate the output file
  p.SetOutputCube("CHECKLINETO", samples, lines, icube->bandCount());

  if (ui.GetString("INTERPOLATION") == "BILINEAR") {
    interp = new Interpolator(Interpolator::BiLinearType);
  }
  else {
    interp = new Interpolator(Interpolator::CubicConvolutionType);
  }
  
  p.StartProcess(*transform, *interp);
  p.EndProcess();
  delete transform;
  delete interp;
}
