module CxxROOT

using Cxx

const ROOT_PATH = "/Users/kfischer/Projects/root/"
const ROOT_OBJ_DIR = joinpath(ROOT_PATH,"obj")

function __init__()
    addHeaderDir(joinpath(ROOT_PATH,"core/base/inc"),kind=C_System)
    addHeaderDir(joinpath(ROOT_PATH,"core/meta/inc"),kind=C_System)
    addHeaderDir(joinpath(ROOT_PATH,"core/metautils/inc"),kind=C_System)
    addHeaderDir(joinpath(ROOT_PATH,"core/meta/src"),kind=C_System)
    addHeaderDir(joinpath(ROOT_PATH,"interpreter/cling/include"),kind=C_System)
    addHeaderDir(joinpath(ROOT_OBJ_DIR,"include"),kind=C_System)
    Libdl.dlopen(joinpath(ROOT_OBJ_DIR,"lib/libCore.so"), Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
    Libdl.dlopen(joinpath(ROOT_OBJ_DIR,"lib/libCling.so"), Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
    cxx"""
        #include "TROOT.h"
        #include "TInterpreter.h"
        #include "TSystem.h"
        #include "TClass.h"
        #include "TApplication.h"
        #include "TPluginManager.h"
        #include "cling/Interpreter/LookupHelper.h"
        #include "clang/AST/ASTContext.h"
        #include "clang/Sema/Lookup.h"
        #include <iostream>
    """
    cxxinclude(joinpath(dirname(@__FILE__),"TCxx.cxx"))
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
    true
end

@cxxm "void TCxx::GetInterpreterTypeName(const char* name, std::string &output, Bool_t full)" begin
    icxx"$output = $name;"
    nothing
end

cxx"""
TClass *TCxx::GenerateTClass(const char *classname, Bool_t emulation, Bool_t silent) {
    Version_t version = 1;
    return new TClass(classname, version, silent);
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

MethodInfo_t  *TCxx::MethodInfo_Factory(DeclId_t declid) const
{
    return (MethodInfo_t *)declid;
}

// TODO: Refactor Cling and use this directly
long TCxx::MethodInfo_Property(MethodInfo_t *MI) const
{
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

long TCxx::ClassInfo_Property(ClassInfo_t *cl) const
{
  clang::Decl *fDecl = (clang::Decl*)((TCxxClassInfo*)cl)->decl;
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

int TCxx::MethodInfo_NArg(MethodInfo_t *MI) const
{
    clang::FunctionDecl *FD = (clang::FunctionDecl*)MI;
    std::cout << "Requested for:" << std::endl;
    FD->dump();
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
    return (ClassInfo_t*)new TCxxClassInfo;
}

ClassInfo_t  *TCxx::ClassInfo_Factory(ClassInfo_t * /* cl */) const {
    assert(false);
}

ClassInfo_t  *TCxx::ClassInfo_Factory(const char * /* name */) const {
    assert(false);
}

const char *TCxx::ClassInfo_FileName(ClassInfo_t * /* info */) const {
  return 0;
}

const char *TCxx::ClassInfo_FullName(ClassInfo_t * /* info */) const {
  return 0;
}

const char *TCxx::ClassInfo_Name(ClassInfo_t * /* info */) const {
  return 0;
}

const char *TCxx::ClassInfo_Title(ClassInfo_t * /* info */) const {
  return 0;
}

const char *TCxx::ClassInfo_TmpltName(ClassInfo_t * /* info */) const {
  return 0;
}

void TCxx::ClassInfo_Delete(ClassInfo_t * /* info */) const {
  return;
}

"""
#=
@cxxm "TClass *TCxx::GenerateTClass(const char *classname, Bool_t emulation, Bool_t silent)" begin
    icxx"new TClass($classname, $version, $silent);"
end
=#

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
    ReadRootmap(bytestring(rootmapfile))
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

@cxxm "void TCxx::SetClassInfo(TClass *cl, Bool_t reload)" begin
    @show reload
    name = bytestring(icxx"$cl->GetName();");
    T = cxxparse(Cxx.instance(__current_compiler__), name, true)
    RD = Cxx.getAsCXXRecordDecl(T)
    icxx"""
      TCxxClassInfo *CI = new TCxxClassInfo;
      CI->decl = $RD;
      $cl->fClassInfo = (ClassInfo_t*)CI;
    """
    nothing
end

@cxxm "void TCxx::CreateListOfBaseClasses(TClass *cl) const" begin
    nothing
end

C = Cxx.instance(__current_compiler__)
const LH = icxx"new cling::LookupHelper($(C.Parser),nullptr);"

cxx"""
static bool filterFD(clang::FunctionDecl *ProposedFD, clang::ParmVarDecl **compare, size_t nparams) {
  size_t i = 0;
  if (ProposedFD->getNumParams() < nparams)
      return true;
  for (clang::ParmVarDecl *PVD : ProposedFD->params()) {
      if (i >= nparams) {
          i++;
          PVD->dump();
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

    @show RD
    @show params
    @show icxx"$RD->getName();"

    # Check if we're looking for the constructor
    if bytestring(method) == bytestring(icxx"$RD->getName();")
        FD = icxx"""
        for (clang::FunctionDecl *ctor : $RD->ctors()) {
          std::cout << "Dumping possibility (ctor)" << std::endl;
          ctor->dump();
          if (!filterFD(ctor,$(pointer(params)),$(length(params))))
            return ctor;
        }
        return (clang::FunctionDecl*)nullptr;
        """
    else
        FD = pcpp"clang::FunctionDecl"(icxx"""
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
            std::cout << "Dumping possibility" << std::endl;
            ND->dump();
            if (filterFD(clang::cast<clang::FunctionDecl>(ND),
                $(pointer(params)),$(length(params)))) {
                F.erase();
            }
        }
        F.done();

        return Result.getRepresentativeDecl();
        """.ptr)
    end
    @assert FD != C_NULL
    FD
end

@cxxm "TCxx::DeclId_t TCxx::GetFunctionWithPrototype(ClassInfo_t *cl, const char* method, const char* proto, Bool_t objectIsConst, ROOT::EFunctionMatchMode mode)" begin
    FD = prototype_match(cl,method,proto)
    FD.ptr
end

@cxxm "Bool_t TCxx::ClassInfo_Contains(ClassInfo_t *info, DeclId_t decl) const" begin
    RD = icxx"(clang::CXXRecordDecl*)((TCxxClassInfo*)$info)->decl;"
    @assert RD != C_NULL

    FD = pcpp"clang::CXXMethodDecl"(decl)
    @assert FD != C_NULL
    icxx"""
        //$RD->dump();
        $FD->dump();
    """
    icxx"$FD->getParent();" == RD
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
  icxx"$(CallFunc.method)->dump();"
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
