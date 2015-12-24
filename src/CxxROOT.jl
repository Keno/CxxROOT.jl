module CxxROOT

using Cxx
import CxxStd

const ROOT_PATH = "/Users/kfischer/Projects/root/"
const ROOT_OBJ_DIR = joinpath(ROOT_PATH,"obj-debug")

function __init__()
    addHeaderDir(joinpath(ROOT_PATH,"core/base/inc"),kind=C_System)
    addHeaderDir(joinpath(ROOT_PATH,"core/meta/inc"),kind=C_System)
    addHeaderDir(joinpath(ROOT_PATH,"core/metautils/inc"),kind=C_System)
    addHeaderDir(joinpath(ROOT_PATH,"core/meta/src"),kind=C_System)
    addHeaderDir(joinpath(ROOT_PATH,"interpreter/cling/include"),kind=C_System)
    addHeaderDir(joinpath(ROOT_OBJ_DIR,"include"),kind=C_System)
    Libdl.dlopen(joinpath(ROOT_OBJ_DIR,"lib/libCore.so"), Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
    #Libdl.dlopen(joinpath(ROOT_OBJ_DIR,"lib/libCling.so"), Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
    cxx"""
        // For hardcoded friend classes
        #define TCling TCxx
        #include "TROOT.h"
        #include "TInterpreter.h"
        #include "TSystem.h"
        #include "TClass.h"
        #include "TBaseClass.h"
        #include "TApplication.h"
        #include "TPluginManager.h"
        #include "TMemberInspector.h"
        #include "TDataMember.h"
        #include "clang/AST/ASTContext.h"
        #include "clang/Sema/Lookup.h"
        #include "clang/AST/CXXInheritance.h"
        #include "clang/AST/RecordLayout.h"
        #include <iostream>
    """
    cxxinclude(joinpath(dirname(@__FILE__),"TCxx.cxx"))

    Libdl.dlopen("/Users/kfischer/.julia/v0.5/CxxROOT/src/FakeCling.dylib")
end
__init__()

const globalMapFile = Dict{UTF8String,UTF8String}()

macro gDebug(level,expr)
    quote
        if icxx"gDebug;" > $level
            $expr
        end
    end
end

function ReadRootmap(file; mapfile = globalMapFile)
    decls = IOBuffer()
    open(file,"r") do f
        l = eachline(f)
        it = start(l)
        local libname
        while !done(l,it)
            line, it = next(l, it)
            line = rstrip(line)
            if startswith(line,"{ decls }")
                while !done(l,it)
                    line, it = next(l,it)
                    line[1] == '[' && break
                    write(decls, line)
                end
            end
            c = line[1]
            if c == '['
                idx = findfirst(line,']')
                idx == 0 && continue
                libname = line[2:idx-1]
                libname = lstrip(libname,' ')
            else
                keyLen = c == 'c' ?  6 :
                         c == 'n' ? 10 :
                         c == 't' ?  8 :
                         c == 'h' ?  7 :
                         c == 'e' ?  5 :
                            continue
                keyname = line[1+keyLen:end]
                if haskey(mapfile, keyname)
                    if libname != mapfile[keyname]
                        if c == 'n'
                            @gDebug 3 info("namespace $keyname found in $(libname)"*
                                           "is already in $(mapfile[keyname])")
                        elseif c == 'h'
                            mapfile[keyname] = string(libname,mapfile[keyname])
                        else
                            warn("$line found in $libname is already in $(mapfile[keyname])")
                        end
                    end
                else
                    mapfile[keyname] = libname
                end
            end
        end
    end
end

function LoadLibraryMap()
    paths = unique(split(bytestring(icxx"gSystem->GetDynamicPath();"),
        OS_NAME == :WIINT ? ';' : ':',keep = false))
    for path in paths
        isdir(path) || continue
        for entry in readdir(path)
            if endswith(entry, "rootmap")
                if entry == ".rootmap"
                    continue
                end
                ReadRootmap(joinpath(path,entry))
            end
        end
    end
end

GetClassSharedLibs(class; map = globalMapFile) = globalMapFile[class]

@cxxm "const char *TCxx::GetClassSharedLibs(const char *cls)" begin
    try
      pointer(GetClassSharedLibs(bytestring(cls)))
    catch
      C_NULL
    end
end

@cxxm "Int_t TCxx::AutoLoad(const char *classname, Bool_t knowDictNotLoaded)" begin
    @show bytestring(classname)
    libs = try
      split(GetClassSharedLibs(bytestring(classname)),' '; keep=false)
    catch
      []
    end
    for lib in libs
        Libdl.dlopen(joinpath(ROOT_OBJ_DIR,"lib",lib), Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
    end
    0
end

function unsafe_load_array(strings::Ptr{Ptr{UInt8}})
    i = 1
    ret = UTF8String[]
    while true
        p = unsafe_load(strings,i)
        if p == C_NULL
            break
        end
        push!(ret,bytestring(p))
        i += 1
    end
    ret
end

@cxxm "void TCxx::RegisterModule(const char* modulename,
                                   const char** headers,
                                   const char** includePaths,
                                   const char* payloadCode,
                                   const char* fwdDeclsCode,
                                   void (* triggerFunc)(),
                                   const TCxx::FwdDeclArgsToKeepCollection_t& fwdDeclArgsToKeep,
                                   const char** classesHeaders)" begin
    @show bytestring(payloadCode)
    fwdDeclsCode != C_NULL && @show bytestring(fwdDeclsCode)
    @show unsafe_load_array(includePaths)
    if payloadCode != C_NULL
        cxxparse(bytestring(payloadCode))
    end
    #=
    @show bytestring(modulename)
    @show unsafe_load_array(headers)

    @show payloadCode != C_NULL ? bytestring(payloadCode) : ""
    @show fwdDeclsCode != C_NULL ? bytestring(fwdDeclsCode) : ""
    @show unsafe_load_array(classesHeaders)
    =#
    nothing
end

@cxxm "Bool_t TCxx::CheckClassInfo(const char *name, Bool_t autoload, Bool_t isClassOrNamespaceOnly)" begin
    name = bytestring(name);
    try
      cxxparse(Cxx.instance(__current_compiler__), name, true)
      true
    catch
      false
    end
end

@cxxm "void TCxx::GetInterpreterTypeName(const char* name, std::string &output, Bool_t full)" begin
    icxx"$output = $name;"
    nothing
end

cxx"""
TClass *TCxx::GenerateTClass(const char *classname, Bool_t emulation, Bool_t silent) {
    Version_t version = 1;
    TClass *cl = new TClass(classname, version, silent);
    return cl;
}

TClass *TCxx::GenerateTClass(ClassInfo_t *classinfo, Bool_t silent) {
    TClass *cl = new TClass(classinfo, 1, 0, 0, -1, -1, silent);
    TClass::AddClassToDeclIdMap((TCxx::DeclId_t)((TCxxClassInfo*)classinfo)->decl, cl);
    return cl;
}

void TCxx::SaveContext()
{
    return;
}

void TCxx::SaveGlobalsContext()
{
    return;
}

void TCxx::ResetGlobals()
{
    return;
}

void TCxx::UnRegisterTClassUpdate(const TClass *oldcl)
{
    return;
}

Long_t TCxx::ExecuteMacro(const char* filename, EErrorCode* error)
{
   Long_t result = TApplication::ExecuteFile(filename, (int*)error);
   return result;
}

Long_t TCxx::ProcessLineSynch(const char *line, EErrorCode *error)
{
    return ProcessLine(line, error);
}

Int_t TCxx::AutoParse(const char *cls)
{
    return AutoLoad(cls);
}

Bool_t TCxx::IsAutoParsingSuspended() const
{
    return true;
}

const char *TCxx::GetSharedLibs()
{
    return "";
}

const char *TCxx::GetSharedLibDeps(const char* lib)
{
    return 0;
}

MethodInfo_t  *TCxx::MethodInfo_Factory(DeclId_t declid) const {
    return (MethodInfo_t *)declid;
}

// TODO: Refactor Cling and use this directly
long TCxx::MethodInfo_Property(MethodInfo_t *MI) const {
   long property = 0L;
   property |= kIsCompiled;
   const clang::FunctionDecl *fd = (clang::FunctionDecl *)MI;
   switch (fd->getAccess()) {
      case clang::AS_public:
         property |= kIsPublic;
         break;
      case clang::AS_protected:
         property |= kIsProtected;
         break;
      case clang::AS_private:
         property |= kIsPrivate;
         break;
      case clang::AS_none:
         if (fd->getDeclContext()->isNamespace())
            property |= kIsPublic;
         break;
      default:
         // IMPOSSIBLE
         break;
   }
   if (fd->getStorageClass() == clang::SC_Static) {
      property |= kIsStatic;
   }
   clang::QualType qt = fd->getReturnType().getCanonicalType();
   if (qt.isConstQualified()) {
      property |= kIsConstant;
   }
   while (1) {
      if (qt->isArrayType()) {
         qt = llvm::cast<clang::ArrayType>(qt)->getElementType();
         continue;
      }
      else if (qt->isReferenceType()) {
         property |= kIsReference;
         qt = llvm::cast<clang::ReferenceType>(qt)->getPointeeType();
         continue;
      }
      else if (qt->isPointerType()) {
         property |= kIsPointer;
         if (qt.isConstQualified()) {
            property |= kIsConstPointer;
         }
         qt = llvm::cast<clang::PointerType>(qt)->getPointeeType();
         continue;
      }
      else if (qt->isMemberPointerType()) {
         qt = llvm::cast<clang::MemberPointerType>(qt)->getPointeeType();
         continue;
      }
      break;
   }
   if (qt.isConstQualified()) {
      property |= kIsConstant;
   }
   if (const clang::CXXMethodDecl *md =
            llvm::dyn_cast<clang::CXXMethodDecl>(fd)) {
      if (md->getTypeQualifiers() & clang::Qualifiers::Const) {
         property |= kIsConstant | kIsConstMethod;
      }
      if (md->isVirtual()) {
         property |= kIsVirtual;
      }
      if (md->isPure()) {
         property |= kIsPureVirtual;
      }
      if (const clang::CXXConstructorDecl *cd =
               llvm::dyn_cast<clang::CXXConstructorDecl>(md)) {
         if (cd->isExplicit()) {
            property |= kIsExplicit;
         }
      }
      else if (const clang::CXXConversionDecl *cd =
                  llvm::dyn_cast<clang::CXXConversionDecl>(md)) {
         if (cd->isExplicit()) {
            property |= kIsExplicit;
         }
      }
   }
   return property;
}

static clang::CharUnits computeOffsetHint(clang::ASTContext &Context,
                                          const clang::CXXRecordDecl *Src,
                                          const clang::CXXRecordDecl *Dst) {
   clang::CXXBasePaths Paths(/*FindAmbiguities=*/true, /*RecordPaths=*/true,
                      /*DetectVirtual=*/false);

   // If Dst is not derived from Src we can skip the whole computation below and
   // return that Src is not a public base of Dst.  Record all inheritance paths.
   if (!Dst->isDerivedFrom(Src, Paths))
     return clang::CharUnits::fromQuantity(-2ULL);

   unsigned NumPublicPaths = 0;
   clang::CharUnits Offset;

   // Now walk all possible inheritance paths.
   for (clang::CXXBasePaths::paths_iterator I = Paths.begin(), E = Paths.end();
        I != E; ++I) {

     ++NumPublicPaths;

     for (clang::CXXBasePath::iterator J = I->begin(), JE = I->end(); J != JE; ++J) {
       // If the path contains a virtual base class we can't give any hint.
       // -1: no hint.
       if (J->Base->isVirtual())
         return clang::CharUnits::fromQuantity(-1ULL);

       if (NumPublicPaths > 1) // Won't use offsets, skip computation.
         continue;

       // Accumulate the base class offsets.
       const clang::ASTRecordLayout &L = Context.getASTRecordLayout(J->Class);
       Offset += L.getBaseClassOffset(J->Base->getType()->getAsCXXRecordDecl());
     }
   }

   // -2: Src is not a public base of Dst.
   if (NumPublicPaths == 0)
     return clang::CharUnits::fromQuantity(-2ULL);

   // -3: Src is a multiple public base type but never a virtual base type.
   if (NumPublicPaths > 1)
     return clang::CharUnits::fromQuantity(-3ULL);

   // Otherwise, the Src type is a unique public nonvirtual base type of Dst.
   // Return the offset of Src from the origin of Dst.
   std::cout << "Offset " << Offset.getQuantity() << std::endl;
   return Offset;
 }

Long_t TCxx::BaseClassInfo_Offset(BaseClassInfo_t *toBaseClassInfo, void *address, bool isderived) const {
   // Compute the offset of the derived class to the base class.
   // Check if current base class has a definition.
   const clang::CXXRecordDecl* Base = clang::cast<clang::CXXRecordDecl>(((TCxxBaseClassInfo*)toBaseClassInfo)->parent->decl);
   if (!Base) {
      // No definition yet (just forward declared), invalid.
      return -1;
   }
   // If the base class has no virtual inheritance.
   if (!(BaseClassInfo_Property(toBaseClassInfo) & kIsVirtualBase)) {
      clang::ASTContext& Context = Base->getASTContext();
      const clang::CXXRecordDecl* RD = clang::dyn_cast_or_null<clang::CXXRecordDecl>(((TCxxBaseClassInfo*)toBaseClassInfo)->child->decl);
      if (!RD) {
         // No RecordDecl for the class.
         return -1;
      }
      long clang_val = computeOffsetHint(Context, Base, RD).getQuantity();
      if (clang_val == -2 || clang_val == -3) {
         assert(false);
      }
      return clang_val;
   }
   // Verify the address of the instantiated object
   if (!address) {
      assert(false);
      return -1;
   }

   assert(false);

   return -1;
}

Long_t TCxx::ClassInfo_GetBaseOffset(ClassInfo_t *fromDerived,
                                            ClassInfo_t *toBase, void *address, bool isderived) const
{
  return 0;
}

int TCxx::ClassInfo_Size(ClassInfo_t *info) const {
  clang::Decl *fDecl = ((TCxxClassInfo*)info)->decl;
  clang::Decl::Kind DK = fDecl->getKind();
  if (DK == clang::Decl::Namespace) {
    // Namespaces are special for cint.
    return 1;
  }
  else if (DK == clang::Decl::Enum) {
    // Enums are special for cint.
    return 0;
  }
  const clang::RecordDecl *RD = llvm::dyn_cast<clang::RecordDecl>(fDecl);
  assert(RD);
  if (!RD->getDefinition()) {
    // Forward-declared class.
    return 0;
  }
  clang::ASTContext &Context = fDecl->getASTContext();
  const clang::ASTRecordLayout &Layout = Context.getASTRecordLayout(RD);
  int64_t size = Layout.getSize().getQuantity();
  int clang_size = static_cast<int>(size);
  return clang_size;
}

long TCxx::ClassInfo_Property(ClassInfo_t *cl) const
{
  clang::Decl *fDecl = (clang::Decl*)((TCxxClassInfo*)cl)->decl;
  if (!fDecl)
    return 0;
  long property = 0L;
  property |= kIsCPPCompiled;
  const clang::DeclContext *ctxt = fDecl->getDeclContext();
  clang::NamespaceDecl *std_ns = $:(Cxx.instance(Cxx.__default_compiler__).CI::pcpp"clang::CompilerInstance")->getSema().getStdNamespace();
  while (! ctxt->isTranslationUnit())  {
  if (ctxt->Equals(std_ns)) {
     property |= kIsDefinedInStd;
     break;
  }
  ctxt = ctxt->getParent();
  }
  clang::Decl::Kind DK = fDecl->getKind();
  if ((DK == clang::Decl::Namespace) || (DK == clang::Decl::TranslationUnit)) {
  property |= kIsNamespace;
  return property;
  }
  // Note: Now we have class, enum, struct, union only.
  const clang::TagDecl *TD = llvm::dyn_cast<clang::TagDecl>(fDecl);
  if (!TD) {
  return 0L;
  }
  if (TD->isEnum()) {
  property |= kIsEnum;
  return property;
  }
  // Note: Now we have class, struct, union only.
  const clang::CXXRecordDecl *CRD =
  llvm::dyn_cast<clang::CXXRecordDecl>(fDecl);
  if (CRD->isClass()) {
    property |= kIsClass;
  }
  else if (CRD->isStruct()) {
    property |= kIsStruct;
  }
  else if (CRD->isUnion()) {
    property |= kIsUnion;
  }
  if (CRD->hasDefinition() && CRD->isAbstract()) {
    property |= kIsAbstract;
  }
  return property;
}

long TCxx::ClassInfo_ClassProperty(ClassInfo_t *cl) const {
  long property = 0L;
   const clang::RecordDecl *RD = (clang::RecordDecl*)((TCxxClassInfo*)cl)->decl;
   if (!RD) {
      // We are an enum or namespace.
      // The cint interface always returns 0L for these guys.
      return property;
   }
   if (RD->isUnion()) {
      // The cint interface always returns 0L for these guys.
      return property;
   }
   // We now have a class or a struct.
   const clang::CXXRecordDecl *CRD = llvm::dyn_cast<clang::CXXRecordDecl>(RD);
   property |= kClassIsValid;
   if (CRD->isAbstract()) {
      property |= kClassIsAbstract;
   }
   if (CRD->hasUserDeclaredConstructor()) {
      property |= kClassHasExplicitCtor;
   }
   if (
      !CRD->hasUserDeclaredConstructor() &&
      !CRD->hasTrivialDefaultConstructor()
   ) {
      property |= kClassHasImplicitCtor;
   }
   if (
      CRD->hasUserProvidedDefaultConstructor() ||
      !CRD->hasTrivialDefaultConstructor()
   ) {
      property |= kClassHasDefaultCtor;
   }
   if (CRD->hasUserDeclaredDestructor()) {
      property |= kClassHasExplicitDtor;
   }
   else if (!CRD->hasTrivialDestructor()) {
      property |= kClassHasImplicitDtor;
   }
   if (CRD->hasUserDeclaredCopyAssignment()) {
      property |= kClassHasAssignOpr;
   }
   if (CRD->isPolymorphic()) {
      property |= kClassHasVirtual;
   }
   return property;
}

Long_t TCxx::BaseClassInfo_Property(BaseClassInfo_t *bcinfo) const {
   long property = 0L;

   property |= kIsDirectInherit;

   TCxxBaseClassInfo *BCI = (TCxxBaseClassInfo*)bcinfo;

   const clang::CXXRecordDecl* CRD
      = llvm::dyn_cast<clang::CXXRecordDecl>(BCI->child->decl);
   const clang::CXXRecordDecl* BaseCRD
      = llvm::dyn_cast<clang::CXXRecordDecl>(BCI->parent->decl);
   if (!CRD || !BaseCRD) {
      Error("TClingBaseClassInfo::Property",
            "The derived class or the base class do not have a CXXRecordDecl.");
      return property;
   }

   clang::CXXBasePaths Paths(/*FindAmbiguities=*/false, /*RecordPaths=*/true,
                             /*DetectVirtual=*/true);
   if (!CRD->isDerivedFrom(BaseCRD, Paths)) {
      // Error really unexpected here, because construction / iteration guarantees
      //inheritance;
      Error("TClingBaseClassInfo", "Class not derived from given base.");
   }
   if (Paths.getDetectedVirtual()) {
      property |= kIsVirtualBase;
   }

   clang::AccessSpecifier AS = clang::AS_public;
   // Derived: public Mid; Mid : protected Base: Derived inherits protected Base?
   for (clang::CXXBasePaths::const_paths_iterator IB = Paths.begin(), EB = Paths.end();
        AS != clang::AS_private && IB != EB; ++IB) {
      switch (IB->Access) {
         // keep AS unchanged?
         case clang::AS_public: break;
         case clang::AS_protected: AS = clang::AS_protected; break;
         case clang::AS_private: AS = clang::AS_private; break;
         case clang::AS_none: break;
      }
   }
   switch (AS) {
      case clang::AS_public:
         property |= kIsPublic;
         break;
      case clang::AS_protected:
         property |= kIsProtected;
         break;
      case clang::AS_private:
         property |= kIsPrivate;
         break;
      case clang::AS_none:
         // IMPOSSIBLE
         break;
   }
   return property;
}

int TCxx::MethodInfo_NArg(MethodInfo_t *MI) const
{
    clang::FunctionDecl *FD = (clang::FunctionDecl*)MI;
    return FD->getNumParams();
}

int TCxx::MethodInfo_NDefaultArg(MethodInfo_t *MI) const
{
    clang::FunctionDecl *FD = (clang::FunctionDecl*)MI;
    return FD->getNumParams() - FD->getMinRequiredArguments();
}

TCxx::DeclId_t TCxx::GetDeclId(MethodInfo_t *MI) const
{
    clang::FunctionDecl *FD = (clang::FunctionDecl*)MI;
    return FD->getCanonicalDecl();
}

ClassInfo_t  *TCxx::ClassInfo_Factory(Bool_t /*all*/) const {
    return (ClassInfo_t*)new TCxxClassInfo(nullptr,clang::QualType());
}

ClassInfo_t  *TCxx::ClassInfo_Factory(ClassInfo_t *cl) const {
    return (ClassInfo_t*)new TCxxClassInfo(*(TCxxClassInfo*)cl);
}

const char *TCxx::ClassInfo_FileName(ClassInfo_t * /* info */) const {
  return 0;
}

const char *TCxx::ClassInfo_Name(ClassInfo_t * /* info */) const {
  return 0;
}

const char *TCxx::ClassInfo_Title(ClassInfo_t * /* info */) const {
  return 0;
}

static std::string output;
const char *TCxx::ClassInfo_TmpltName(ClassInfo_t *info) const {
  clang::Decl *D = ((TCxxClassInfo*)info)->decl;
  output.clear();
  if (const clang::NamedDecl* ND = llvm::dyn_cast_or_null<clang::NamedDecl>(D)) {
    // Note: This does *not* include the template arguments!
    output = ND->getNameAsString();
  }
  return output.c_str();
}

const char *TCxx::BaseClassInfo_TmpltName(BaseClassInfo_t *bcinfo) const {
  return ClassInfo_TmpltName(BaseClassInfo_ClassInfo(bcinfo));
}

void TCxx::ClassInfo_Delete(ClassInfo_t * /* info */) const {
  return;
}

void TCxx::CreateListOfBaseClasses(TClass *cl) const {
  auto *info = ((TCxxClassInfo*)cl->fClassInfo);
  if (!info)
    return;
  clang::CXXRecordDecl *RD = (clang::CXXRecordDecl*)info->decl;
  if (!RD)
    return;
  cl->fBase = new TList;
  for (auto base : RD->bases()) {
    auto *BCI = new TCxxBaseClassInfo;
    BCI->child = llvm::make_unique<TCxxClassInfo>(*info);
    BCI->parent = llvm::make_unique<TCxxClassInfo>(base.getType()->getAsCXXRecordDecl(),base.getType());
    cl->fBase->Add(new TBaseClass((BaseClassInfo_t *)BCI,cl));
  }
}

ClassInfo_t *TCxx::BaseClassInfo_ClassInfo(BaseClassInfo_t *bcinfo) const {
  return (ClassInfo_t*)((TCxxBaseClassInfo*)bcinfo)->parent.get();
}

Bool_t TCxx::ClassInfo_IsValid(ClassInfo_t *info) const {
  return info && ((TCxxClassInfo*)info)->decl;
}

static const char *getNDName(clang::Decl *D, bool Qualified)
{
  output.clear();
   if (const clang::NamedDecl *nd = llvm::dyn_cast<clang::NamedDecl>(D)) {
      clang::PrintingPolicy policy(nd->getASTContext().getPrintingPolicy());
      llvm::raw_string_ostream stream(output);
      nd->getNameForDiagnostic(stream, policy, Qualified);
      stream.flush();
      return output.c_str();
   }
   return 0;
}

const char *TCxx::ClassInfo_FullName(ClassInfo_t *info) const {
  return getNDName(((TCxxClassInfo*)info)->decl,true);
}

void TCxx::InspectMembers(TMemberInspector &insp, const void* obj, const TClass* cl, Bool_t isTransient) {
{
   if (insp.GetObjectValidity() == TMemberInspector::kUnset) {
      insp.SetObjectValidity(obj ? TMemberInspector::kValidObjectGiven
                             : TMemberInspector::kNoObjectGiven);
   }

   if (!cl || cl->GetCollectionProxy()) {
      // We do not need to investigate the content of the STL
      // collection, they are opaque to us (and details are
      // uninteresting).
      return;
   }

   static const TClassRef clRefString("std::string");
   if (clRefString == cl) {
      // We stream std::string without going through members..
      return;
   }

   const char* cobj = (const char*) obj; // for ptr arithmetics

   // For now ignore std::complex

   static clang::PrintingPolicy
      printPol($:(Cxx.instance(Cxx.__default_compiler__).CI::pcpp"clang::CompilerInstance")->getLangOpts());
   if (printPol.Indentation) {
      // not yet initialized
      printPol.Indentation = 0;
      printPol.SuppressInitializers = true;
   }

   const char* clname = cl->GetName();
   // Printf("Inspecting class %s\n", clname);

   const clang::ASTContext& astContext = $:(Cxx.instance(Cxx.__default_compiler__).CI::pcpp"clang::CompilerInstance")->getASTContext();
   const clang::Decl *scopeDecl = 0;
   const clang::Type *recordType = 0;

   assert(cl->GetClassInfo());

  auto *CI = (TCxxClassInfo *)cl->GetClassInfo();
   scopeDecl = CI->decl;
   const clang::CXXRecordDecl* recordDecl
     = llvm::dyn_cast_or_null<const clang::CXXRecordDecl>(scopeDecl);
   assert(recordDecl);

   const clang::ASTRecordLayout& recLayout
      = astContext.getASTRecordLayout(recordDecl);

   assert(cl->Size() == recLayout.getSize().getQuantity());

   unsigned iNField = 0;
   // iterate over fields
   // FieldDecls are non-static, else it would be a VarDecl.
   for (auto iField : recordDecl->fields()) {

      clang::QualType memberQT = iField->getType();
      const clang::Type* memType = memberQT.getTypePtr();
      assert(memType);
      const clang::Type* memNonPtrType = memType;
      Bool_t ispointer = false;
      if (memNonPtrType->isPointerType()) {
         ispointer = true;
         clang::QualType ptrQT = memNonPtrType->getAs<clang::PointerType>()->getPointeeType();
         memNonPtrType = ptrQT.getTypePtr();
      }

      // assemble array size(s): "[12][4][]"
      llvm::SmallString<8> arraySize;
      const clang::ArrayType* arrType = memNonPtrType->getAsArrayTypeUnsafe();
      unsigned arrLevel = 0;
      while (arrType) {
         ++arrLevel;
         arraySize += '[';
         const clang::ConstantArrayType* constArrType =
         clang::dyn_cast<clang::ConstantArrayType>(arrType);
         if (constArrType) {
            constArrType->getSize().toStringUnsigned(arraySize);
         }
         arraySize += ']';
         clang::QualType subArrQT = arrType->getElementType();
         assert(!subArrQT.isNull());
         arrType = subArrQT.getTypePtr()->getAsArrayTypeUnsafe();
      }

      // construct member name
      std::string fieldName;
      if (memType->isPointerType()) {
         fieldName = "*";
      }

      // Check if this field has a custom ioname, if not, just use the one of the decl
      std::string ioname(iField->getName());
      // ROOT::TMetaUtils::ExtractAttrPropertyFromName(**iField,"ioname",ioname);
      fieldName += ioname;
      fieldName += arraySize;

      // get member offset
      // NOTE currently we do not support bitfield and do not support
      // member that are not aligned on 'bit' boundaries.
      clang::CharUnits offset(astContext.toCharUnitsFromBits(recLayout.getFieldOffset(iNField)));
      ptrdiff_t fieldOffset = offset.getQuantity();

      insp.Inspect(const_cast<TClass*>(cl), insp.GetParent(), fieldName.c_str(), cobj + fieldOffset, isTransient);

      if (!ispointer) {
         const clang::CXXRecordDecl* fieldRecDecl = memNonPtrType->getAsCXXRecordDecl();
         if (fieldRecDecl) {
            // nested objects get an extra call to InspectMember
            std::string sFieldRecName;

            TDataMember* mbr = cl->GetDataMember(ioname.c_str());
            // if we can not find the member (which should not really happen),
            // let's consider it transient.
            Bool_t transient = isTransient || !mbr || !mbr->IsPersistent();

            insp.InspectMember(sFieldRecName.c_str(), cobj + fieldOffset,
                               (fieldName + '.').c_str(), transient);

         }
      }
   } // loop over fields

   // inspect bases
   // TNamed::ShowMembers(R__insp);
   unsigned iNBase = 0;
   for (auto iBase : recordDecl->bases()) {
      clang::QualType baseQT = iBase.getType();
      assert(!baseQT.isNull());
      const clang::CXXRecordDecl* baseDecl
         = baseQT->getAsCXXRecordDecl();
      assert(baseDecl);
      TClass* baseCl=nullptr;
      std::string sBaseName;
      // Try with the DeclId
      std::vector<TClass*> foundClasses;
      TClass::GetClass(static_cast<DeclId_t>(baseDecl), foundClasses);
      if (foundClasses.size()==1){
         baseCl=foundClasses[0];
      } else {
        std::cout << "Found " << foundClasses.size() << " classes";
        baseDecl->dump();
        assert(false);
      }

      assert(baseCl);

      int64_t baseOffset;
      if (iBase.isVirtual()) {
         assert(false && "isVirtual");
      } else {
         baseOffset = recLayout.getBaseClassOffset(baseDecl).getQuantity();
      }
      // TOFIX: baseCl can be null here!
      if (baseCl->IsLoaded()) {
         // For loaded class, CallShowMember will (especially for TObject)
         // call the virtual ShowMember rather than the class specific version
         // resulting in an infinite recursion.
         InspectMembers(insp, cobj + baseOffset, baseCl, isTransient);
      } else {
        assert(false && "Not loaded");
      }
   } // loop over bases
}
}

TCxx::DeclId_t TCxx::GetDataMember(ClassInfo_t *cl, const char *name) const {
  clang::Preprocessor& PP = $:(Cxx.instance(Cxx.__default_compiler__).CI::pcpp"clang::CompilerInstance")->getSema().getPreprocessor();

  clang::IdentifierInfo *dataII = &PP.getIdentifierTable().get(name);
  clang::DeclarationName decl_name( dataII );

  const clang::DeclContext *dc = llvm::cast<clang::DeclContext>(((TCxxClassInfo*)cl)->decl);

  clang::DeclContext::lookup_result lookup = const_cast<clang::DeclContext*>(dc)->lookup(decl_name);
  for (clang::DeclContext::lookup_iterator I = lookup.begin(), E = lookup.end();
       I != E; ++I) {
    const clang::ValueDecl *result = clang::dyn_cast<clang::ValueDecl>(*I);
    if (result && !clang::isa<clang::FunctionDecl>(result))
      return (clang::Decl*)result;
  }

  return 0;

}

DataMemberInfo_t *TCxx::DataMemberInfo_Factory(DeclId_t declid, ClassInfo_t* clinfo) const {
  return (DataMemberInfo_t *)declid;
}

const char *TCxx::DataMemberInfo_Name(DataMemberInfo_t *dminfo) const {
  return getNDName((clang::Decl*)dminfo,false);
}

Bool_t TCxx::DataMemberInfo_IsValid(DataMemberInfo_t * /* dminfo */) const {
  return true;
}

const char *TCxx::DataMemberInfo_Title(DataMemberInfo_t *dminfo) const {
  return "";
}

static long TypeProperty(clang::QualType QT) {
     long property = 0L;
   if (llvm::isa<clang::TypedefType>(*QT)) {
      property |= kIsTypedef;
   }
   QT = QT.getCanonicalType();
   if (QT.isConstQualified()) {
      property |= kIsConstant;
   }
   while (1) {
      if (QT->isArrayType()) {
         QT = llvm::cast<clang::ArrayType>(QT)->getElementType();
         continue;
      }
      else if (QT->isReferenceType()) {
         property |= kIsReference;
         QT = llvm::cast<clang::ReferenceType>(QT)->getPointeeType();
         continue;
      }
      else if (QT->isPointerType()) {
         property |= kIsPointer;
         if (QT.isConstQualified()) {
            property |= kIsConstPointer;
         }
         QT = llvm::cast<clang::PointerType>(QT)->getPointeeType();
         continue;
      }
      else if (QT->isMemberPointerType()) {
         QT = llvm::cast<clang::MemberPointerType>(QT)->getPointeeType();
         continue;
      }
      break;
   }
   if (QT->isBuiltinType()) {
      property |= kIsFundamental;
   }
   if (QT.isConstQualified()) {
      property |= kIsConstant;
   }
   const clang::TagType *tagQT = llvm::dyn_cast<clang::TagType>(QT.getTypePtr());
   if (tagQT) {
      // Note: Now we have class, enum, struct, union only.
      const clang::TagDecl *TD = llvm::dyn_cast<clang::TagDecl>(tagQT->getDecl());
      if (TD->isEnum()) {
         property |= kIsEnum;
      } else {
         // Note: Now we have class, struct, union only.
         const clang::CXXRecordDecl *CRD =
            llvm::dyn_cast<clang::CXXRecordDecl>(TD);
         if (CRD->isClass()) {
            property |= kIsClass;
         }
         else if (CRD->isStruct()) {
            property |= kIsStruct;
         }
         else if (CRD->isUnion()) {
            property |= kIsUnion;
         }
         if (CRD->isThisDeclarationADefinition() && CRD->isAbstract()) {
            property |= kIsAbstract;
         }
      }
   }
   return property;
}

Long_t TCxx::DataMemberInfo_Property(DataMemberInfo_t *dminfo) const {
   long property = 0L;
   const clang::Decl *declaccess = (clang::Decl*)dminfo;
   if (declaccess->getDeclContext()->isTransparentContext()) {
      declaccess = llvm::dyn_cast<clang::Decl>(declaccess->getDeclContext());
      if (!declaccess) declaccess = (clang::Decl*)dminfo;
   }
   switch (declaccess->getAccess()) {
      case clang::AS_public:
         property |= kIsPublic;
         break;
      case clang::AS_protected:
         property |= kIsProtected;
         break;
      case clang::AS_private:
         property |= kIsPrivate;
         break;
      case clang::AS_none:
         if (declaccess->getDeclContext()->isNamespace()) {
            property |= kIsPublic;
         } else {
            // IMPOSSIBLE
         }
         break;
      default:
         // IMPOSSIBLE
         break;
   }
   if (const clang::VarDecl *vard = llvm::dyn_cast<clang::VarDecl>((clang::Decl*)dminfo)) {
      if (vard->getStorageClass() == clang::SC_Static) {
         property |= kIsStatic;
      } else if (declaccess->getDeclContext()->isNamespace()) {
         // Data members of a namespace are global variable which were
         // considered to be 'static' in the CINT (and thus ROOT) scheme.
         property |= kIsStatic;
      }
   }
   if (llvm::isa<clang::EnumConstantDecl>((clang::Decl*)dminfo)) {
      // Enumeration constant are considered to be 'static' data member in
      // the CINT (and thus ROOT) scheme.
      property |= kIsStatic;
   }
   const clang::ValueDecl *vd = llvm::dyn_cast<clang::ValueDecl>((clang::Decl*)dminfo);
   clang::QualType qt = vd->getType();
   if (llvm::isa<clang::TypedefType>(qt)) {
      property |= kIsTypedef;
   }
   qt = qt.getCanonicalType();
   if (qt.isConstQualified()) {
      property |= kIsConstant;
   }
   while (1) {
      if (qt->isArrayType()) {
         property |= kIsArray;
         qt = llvm::cast<clang::ArrayType>(qt)->getElementType();
         continue;
      }
      else if (qt->isReferenceType()) {
         property |= kIsReference;
         qt = llvm::cast<clang::ReferenceType>(qt)->getPointeeType();
         continue;
      }
      else if (qt->isPointerType()) {
         property |= kIsPointer;
         if (qt.isConstQualified()) {
            property |= kIsConstPointer;
         }
         qt = llvm::cast<clang::PointerType>(qt)->getPointeeType();
         continue;
      }
      else if (qt->isMemberPointerType()) {
         qt = llvm::cast<clang::MemberPointerType>(qt)->getPointeeType();
         continue;
      }
      break;
   }
   if (qt->isBuiltinType()) {
      property |= kIsFundamental;
   }
   if (qt.isConstQualified()) {
      property |= kIsConstant;
   }
   const clang::TagType *tt = qt->getAs<clang::TagType>();
   if (tt) {
      const clang::TagDecl *td = tt->getDecl();
      if (td->isClass()) {
         property |= kIsClass;
      }
      else if (td->isStruct()) {
         property |= kIsStruct;
      }
      else if (td->isUnion()) {
         property |= kIsUnion;
      }
      else if (td->isEnum()) {
         property |= kIsEnum;
      }
   }
   // We can't be a namespace, can we?
   //   if (dc->isNamespace() && !dc->isTranslationUnit()) {
   //      property |= kIsNamespace;
   //   }
   return property;
}

Long_t TCxx::DataMemberInfo_TypeProperty(DataMemberInfo_t *dminfo) const {
  return TypeProperty(clang::cast<clang::ValueDecl>((clang::Decl*)dminfo)->getType());
}

int TCxx::DataMemberInfo_ArrayDim(DataMemberInfo_t *dminfo) const {
   // Sanity check the current data member.
   clang::Decl::Kind DK = ((clang::Decl*)dminfo)->getKind();
   if (
       (DK != clang::Decl::Field) &&
       (DK != clang::Decl::Var) &&
       (DK != clang::Decl::EnumConstant)
       ) {
      // Error, was not a data member, variable, or enumerator.
      return -1;
   }
   if (DK == clang::Decl::EnumConstant) {
      // We know that an enumerator value does not have array type.
      return 0;
   }
   // To get this information we must count the number
   // of array type nodes in the canonical type chain.
   const clang::ValueDecl *VD = llvm::dyn_cast<clang::ValueDecl>(((clang::Decl*)dminfo));
   clang::QualType QT = VD->getType().getCanonicalType();
   int cnt = 0;
   while (1) {
      if (QT->isArrayType()) {
         ++cnt;
         QT = llvm::cast<clang::ArrayType>(QT)->getElementType();
         continue;
      }
      else if (QT->isReferenceType()) {
         QT = llvm::cast<clang::ReferenceType>(QT)->getPointeeType();
         continue;
      }
      else if (QT->isPointerType()) {
         QT = llvm::cast<clang::PointerType>(QT)->getPointeeType();
         continue;
      }
      else if (QT->isMemberPointerType()) {
         QT = llvm::cast<clang::MemberPointerType>(QT)->getPointeeType();
         continue;
      }
      break;
   }
   return cnt;
}

int TCxx::DataMemberInfo_MaxIndex(DataMemberInfo_t *dminfo, Int_t dim) const {
  clang::Decl::Kind DK = ((clang::Decl*)dminfo)->getKind();
   if (
       (DK != clang::Decl::Field) &&
       (DK != clang::Decl::Var) &&
       (DK != clang::Decl::EnumConstant)
       ) {
      // Error, was not a data member, variable, or enumerator.
      return -1;
   }
   if (DK == clang::Decl::EnumConstant) {
      // We know that an enumerator value does not have array type.
      return 0;
   }
   // To get this information we must count the number
   // of array type nodes in the canonical type chain.
   const clang::ValueDecl *VD = llvm::dyn_cast<clang::ValueDecl>((clang::Decl*)dminfo);
   clang::QualType QT = VD->getType().getCanonicalType();
   int paran = DataMemberInfo_ArrayDim(dminfo);
   if ((dim < 0) || (dim >= paran)) {
      // Passed dimension is out of bounds.
      return -1;
   }
   int cnt = dim;
   int max = 0;
   while (1) {
      if (QT->isArrayType()) {
         if (cnt == 0) {
            if (const clang::ConstantArrayType *CAT =
                llvm::dyn_cast<clang::ConstantArrayType>(QT)
                ) {
               max = static_cast<int>(CAT->getSize().getZExtValue());
            }
            else if (llvm::dyn_cast<clang::IncompleteArrayType>(QT)) {
               max = INT_MAX;
            }
            else {
               max = -1;
            }
            break;
         }
         --cnt;
         QT = llvm::cast<clang::ArrayType>(QT)->getElementType();
         continue;
      }
      else if (QT->isReferenceType()) {
         QT = llvm::cast<clang::ReferenceType>(QT)->getPointeeType();
         continue;
      }
      else if (QT->isPointerType()) {
         QT = llvm::cast<clang::PointerType>(QT)->getPointeeType();
         continue;
      }
      else if (QT->isMemberPointerType()) {
         QT = llvm::cast<clang::MemberPointerType>(QT)->getPointeeType();
         continue;
      }
      break;
   }
   return max;
}

static clang::QualType stripArrayType(clang::QualType QT) {
  if (QT->isArrayType()) {
    QT = llvm::cast<clang::ArrayType>(QT)->getElementType();
  }
  return QT;
}

"""

@cxxm "const char *TCxx::DataMemberInfo_TypeName(DataMemberInfo_t *dminfo) const"  begin
  pointer(CxxStd.typename(icxx"stripArrayType(clang::cast<clang::ValueDecl>((clang::Decl*)$dminfo)->getType().getCanonicalType());"))
end

@cxxm "const char *TCxx::DataMemberInfo_TypeTrueName(DataMemberInfo_t *dminfo) const"  begin
  pointer(CxxStd.typename(icxx"stripArrayType(clang::cast<clang::ValueDecl>((clang::Decl*)$dminfo)->getType().getCanonicalType());"))
end

#=
@cxxm "TClass *TCxx::GenerateTClass(const char *classname, Bool_t emulation, Bool_t silent)" begin
    icxx"new TClass($classname, $version, $silent);"
end
=#

@cxxm "const char *TCxx::BaseClassInfo_FullName(BaseClassInfo_t *bcinfo) const" begin
  pointer(CxxStd.typename(icxx"((TCxxBaseClassInfo*)$(bcinfo))->parent->QT;"))
end

@cxxm "Long_t TCxx::ProcessLine(const char *line, EErrorCode *error)" begin
    line = bytestring(line)
    eval(Cxx.process_cxx_string(line, false, false, :ProcessLine, 1, 1; compiler = __current_compiler__))
    0
end

@cxxm "Long_t TCxx::ExecuteMacro(const char *filename, EErrorCode *error)" begin
    filename = bytestring(filename)
    cxxinclude(filename);
    fname = basename(filename)
    fname = fname[1:(findfirst(fname,'.')-1)]
    eval(Cxx.process_cxx_string("$(fname)();", false, false, :ProcessLine, 1, 1; compiler = __current_compiler__))
    0
end

@cxxm "Int_t TCxx::LoadLibraryMap(const char *rootmapfile)" begin
    if rootmapfile == C_NULL
      LoadLibraryMap()
    else
      ReadRootmap(bytestring(rootmapfile))
    end
    0
end

@cxxm "Int_t TCxx::UnloadLibraryMap(const char *library)" begin
    @show bytestring(library)
    0
end

@cxxm "Int_t TCxx::Load(const char *filenam, Bool_t system)" begin
    Libdl.dlopen(joinpath(ROOT_OBJ_DIR,"lib",bytestring(filenam)), Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
    0
end

@cxxm "ClassInfo_t *TCxx::ClassInfo_Factory(const char *name) const" begin
    if isempty(bytestring(name))
      T = Cxx.QualType(C_NULL)
      RD = pcpp"clang::CXXRecordDecl"(C_NULL)
    else
      T = cxxparse(Cxx.instance(__current_compiler__), bytestring(name), true)
      RD = Cxx.getAsCXXRecordDecl(T)
    end
    icxx"(ClassInfo_t*)new TCxxClassInfo($RD,$T);"
end

@cxxm "void TCxx::SetClassInfo(TClass *cl, Bool_t reload)" begin
    name = bytestring(icxx"$cl->GetName();");
    @show name
    T = cxxparse(Cxx.instance(__current_compiler__), name, true)
    RD = Cxx.getAsCXXRecordDecl(T)
    icxx"""
      $cl->fClassInfo = (ClassInfo_t*)new TCxxClassInfo($RD,$T);
      TClass::AddClassToDeclIdMap((TCxx::DeclId_t)$RD, $cl);
    """
    nothing
end



C = Cxx.instance(__current_compiler__)

cxx"""
static bool filterFD(clang::FunctionDecl *ProposedFD, clang::ParmVarDecl **compare, size_t nparams) {
  size_t i = 0;
  if (ProposedFD->getNumParams() < nparams)
      return true;
  for (clang::ParmVarDecl *PVD : ProposedFD->params()) {
      if (i >= nparams) {
          i++;
          if (!PVD->hasDefaultArg())
              return true;
      } else if (PVD->getType() != compare[i++]->getType()) {
          return true;
      }
  }
  return false;
}
"""

function prototype_match(cl,method,proto)
    @show (bytestring(method), bytestring(proto))
    proto = bytestring(proto)
    @assert cl != C_NULL
    RD = icxx"(clang::CXXRecordDecl*)((TCxxClassInfo*)$cl)->decl;"
    @assert RD != C_NULL

    params = pcpp"clang::ParmVarDecl"[]
    if !isempty(proto)
        Cxx.EnterBuffer(Cxx.instance(Cxx.__default_compiler__),proto)
        params = Cxx.ParseParameterList(Cxx.instance(Cxx.__default_compiler__),count(x->x==',',proto)+1)
    end

    # Check if we're looking for the constructor
    if bytestring(method) == bytestring(icxx"$RD->getName();")
        FD = icxx"""
        for (clang::FunctionDecl *ctor : $RD->ctors()) {
          if (!filterFD(ctor,$(pointer(params)),$(length(params))))
            return ctor;
        }
        return (clang::FunctionDecl*)nullptr;
        """
    else
        FD = pcpp"clang::FunctionDecl"(icxx"""
        clang::CXXScopeSpec spec;
        $(C.CI)->getSema().RequireCompleteDeclContext(spec,$RD);
        clang::DeclarationName FuncName(&$(C.CI)->getASTContext().Idents.get($(method)));
        clang::SourceLocation FuncNameLoc = clang::SourceLocation();
        clang::LookupResult Result($(C.CI)->getSema(), FuncName, FuncNameLoc, clang::Sema::LookupMemberName,
                            clang::Sema::NotForRedeclaration);
        Result.suppressDiagnostics();
        if (!$(C.CI)->getSema().LookupQualifiedName(Result, $(RD))) {
            return (clang::NamedDecl*)nullptr;
        }

        clang::LookupResult::Filter F = Result.makeFilter();
        clang::ParmVarDecl **compare = $(pointer(params));
        while (F.hasNext()) {
            clang::NamedDecl *ND = F.next();
            if (filterFD(clang::cast<clang::FunctionDecl>(ND),
                $(pointer(params)),$(length(params)))) {
                F.erase();
            }
        }
        F.done();

        return Result.getRepresentativeDecl();
        """.ptr)
    end
    #@assert FD != C_NULL
    FD
end

@cxxm "TCxx::DeclId_t TCxx::GetFunctionWithPrototype(ClassInfo_t *cl, const char* method, const char* proto, Bool_t objectIsConst, ROOT::EFunctionMatchMode mode)" begin
    try
      FD = prototype_match(cl,method,proto)
      FD.ptr
    catch
      C_NULL
    end
end

@cxxm "Bool_t TCxx::ClassInfo_Contains(ClassInfo_t *info, DeclId_t decl) const" begin
    RD = icxx"(clang::CXXRecordDecl*)((TCxxClassInfo*)$info)->decl;"
    @assert RD != C_NULL
    icxx"""
      clang::Decl *D = (clang::Decl*)$decl;
      return (clang::isa<clang::DeclContext>(D) ? clang::cast<clang::DeclContext>(D)->getParent() :
      clang::isa<clang::FieldDecl>(D) ? clang::cast<clang::FieldDecl>(D)->getParent() :
      nullptr) == $RD;
    """
end

type CallFunc
  method::pcpp"clang::FunctionDecl"
  arg::Vector{Any}
  IgnoreExtraArgs::Bool
  CallFunc() = new(pcpp"clang::FunctionDecl"(C_NULL),Any[],false)
end

const callfuncs = CallFunc[]
@cxxm "CallFunc_t *TCxx::CallFunc_Factory() const" begin
  c = CallFunc()
  push!(callfuncs, c)
  pcpp"CallFunc_t"(pointer_from_objref(c))
end

@cxxm """void TCxx::CallFunc_SetFunc(CallFunc_t *func,
                                     ClassInfo_t *info,
                                     const char *method,
                                     const char *params,
                                     bool objectIsConst,
                                     Long_t *Offset) const""" begin
  CallFunc = unsafe_pointer_to_objref(func.ptr)
  @show (info,method,params)
  @assert false
  nothing
end

@cxxm "void TCxx::CallFunc_SetFunc(CallFunc_t *func, MethodInfo_t *info) const" begin
  CallFunc = unsafe_pointer_to_objref(func.ptr)
  CallFunc.method = pcpp"clang::FunctionDecl"(info.ptr)
  nothing
end

@cxxm "void TCxx::CallFunc_ResetArg(CallFunc_t *func) const" begin
  empty!(unsafe_pointer_to_objref(func.ptr).arg)
  nothing
end

for T in ("Long_t","ULong_t","Float_t","Double_t","Long64_t","ULong64_t")
  @cxxm "void TCxx::CallFunc_SetArg(CallFunc_t *func, $T param) const" begin
    CallFunc = unsafe_pointer_to_objref(func.ptr)
    @show param
    push!(CallFunc.arg,param)
    nothing
  end
end

@cxxm "void TCxx::CallFunc_SetArgArray(CallFunc_t *func, Long_t *paramArr, Int_t nparam) const" begin
  unsafe_pointer_to_objref(func.ptr).arg = copy(pointer_to_array(paramArr, nparam, false))
  nothing
end

const temporaries = Any[]

function exec(func,addr)
  CallFunc = unsafe_pointer_to_objref(func.ptr)
  # Convert arguments to the required types
  types = map(x->x[2],Cxx.extract_params(Cxx.instance(Cxx.__default_compiler__),
    CallFunc.method))
  thisT = types[1]
  types = types[2:end]
  if addr != C_NULL
    thisarg = thisT(addr)
  end
  args = map(zip(CallFunc.arg,types)) do x
    arg, T = x
    # Implicit IntToPtr
    if isa(arg,Integer) && T <: Cxx.CppPtr
      return T(convert(Ptr{Void},arg))
    end
    convert(T,arg)
  end
  if addr != C_NULL
    unshift!(args, thisarg)
  end
  @show args
  # Note ROOT expects constructors to be `new`'ed
  ret = eval(Expr(:call,addr == C_NULL ? Cxx.cxxnewcall : Cxx.cppcall_member,Cxx.__default_compiler__,Val{CallFunc.method}(),args...))
  @show ret
  if isa(ret, Cxx.CppValue)
    push!(temporaries,ret)
    ret = pointer_from_objref(ret)
  end
  @show ret
  ret
end

@cxxm "Long_t TCxx::CallFunc_ExecInt(CallFunc_t *func, void *addr) const" begin
  exec(func,addr)
end

@cxxm "void TCxx::CallFunc_Exec(CallFunc_t *func, void *addr) const" begin
  exec(func,addr)
end


@cxxm "void TCxx::CallFunc_IgnoreExtraArgs(CallFunc_t *func, bool ignore) const" begin
  CallFunc = unsafe_pointer_to_objref(func.ptr)
  CallFunc.IgnoreExtraArgs = ignore
  nothing
end

@cxxm """void TCxx::CallFunc_SetFuncProto(CallFunc_t *func, ClassInfo_t *info, const char *method,
        const char *proto, Long_t *Offset, ROOT::EFunctionMatchMode mode) const""" begin
  @show info
  FD = prototype_match(info,method,proto)
  unsafe_pointer_to_objref(func.ptr).method = FD
  nothing
end

@cxxm "bool TCxxLookupHelper::ExistingTypeCheck(const std::string &tname, std::string &result)" begin
  @show bytestring(tname)
  false
end

@cxxm "bool TCxxLookupHelper::GetPartiallyDesugaredNameWithScopeHandling(const std::string &tname, std::string &result)" begin
  @show bytestring(tname)
  false
end

@cxxm "void TCxx::ClassInfo_Init(ClassInfo_t *info, const char *name) const" begin
  @show bytestring(name)
  @assert info != C_NULL
  decl = Cxx.lookup_name(Cxx.instance(Cxx.__default_compiler__),[bytestring(name)])
  icxx"((TCxxClassInfo*)$info)->decl = $decl;"
  nothing
end

@cxxm "Int_t TCxx::DeleteGlobal(void *obj)" begin
  0
end

@cxxm "void TCxx::RegisterTClassUpdate(TClass *oldcl,DictFuncPtr_t dict)" begin
  nothing
end


# TCollection Iteration
import Base: start, next, done
start(C::pcpp"TCollection") = icxx"$C->begin();"
next(C::pcpp"TCollection",it) = (icxx"*$it;", (icxx"$it.Next();"; it))
done(C::pcpp"TCollection",it) = icxx"$it == $C->end();"


end # module
using Cxx
