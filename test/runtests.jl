using CxxROOT
CxxROOT.LoadLibraryMap()
tcxx = icxx"""new TCxx("C++","Cxx.jl C++ Interpreter");"""
cxx"""
#include "/Users/kfischer/Projects/root/graf2d/x11/inc/TGX11.h"
"""
try
icxx"""
gROOT->GetClass("TGenPhaseSpace");
gROOT->GetClass("TH2F");
gROOT->GetClass("TCanvas");
gROOT->GetClass("TGHtml");
"""
end
app = icxx"""
new TApplication("ROOT Application", NULL, NULL);
"""
icxx"""
if (!gROOT->GetClass("TGenPhaseSpace")) gSystem->Load("libPhysics");
"""
h2 = icxx"""
    new TH2F("h2","h2", 50,1.1,1.8, 50,1.1,1.8);
"""
icxx"""
TLorentzVector target(0.0, 0.0, 0.0, 0.938);
TLorentzVector beam(0.0, 0.0, .65, .65);
TLorentzVector W = beam + target;

//(Momentum, Energy units are Gev/C, GeV)
Double_t masses[3] = { 0.938, 0.139, 0.139} ;

TGenPhaseSpace event;
event.SetDecay(W, 3, masses);

for (Int_t n=0;n<100000;n++) {
  Double_t weight = event.Generate();

  TLorentzVector *pProton = event.GetDecay(0);

  TLorentzVector *pPip    = event.GetDecay(1);
  TLorentzVector *pPim    = event.GetDecay(2);

  TLorentzVector pPPip = *pProton + *pPip;
  TLorentzVector pPPim = *pProton + *pPim;

  $h2->Fill(pPPip.M2() ,pPPim.M2() ,weight);
}
$h2->Draw();
"""
task = @async while true
sleep(0.1)
icxx"gSystem->ProcessEvents();"
end
c1 = icxx"""(TCanvas *)gROOT->GetListOfCanvases()->FindObject("c1");"""
