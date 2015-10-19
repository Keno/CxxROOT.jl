#ifndef ROOT_TCxx
#define ROOT_TCxx

//////////////////////////////////////////////////////////////////////////
//                                                                      //
// TCxx                                                                 //
//                                                                      //
// A TInterpreter based on Cxx.jl.                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////

#include "TInterpreter.h"

class TCxx : public TInterpreter {

private:
   TInterpreter *_fwd;

protected:
   virtual void Execute(TMethod *method, TObjArray *params, int *error = 0) { assert(false); }
   virtual Bool_t SetSuspendAutoParsing(Bool_t value) { assert(false); }


public:

   virtual Bool_t IsAutoParsingSuspended() const;

   TCxx() { }   // for Dictionary
   TCxx(const char *name, const char *title = "Generic Interpreter", TInterpreter *fwd = gCling) : _fwd(fwd), TInterpreter(name,title) {}
   virtual ~TCxx();

   virtual void     AddIncludePath(const char *path) { assert(false); }
   virtual void    *SetAutoLoadCallBack(void* /*cb*/) { return 0; }
   virtual void    *GetAutoLoadCallBack() const { return 0; }
   virtual Int_t    AutoLoad(const char *classname, Bool_t knowDictNotLoaded = kFALSE);
   virtual Int_t    AutoLoad(const std::type_info& typeinfo, Bool_t knowDictNotLoaded = kFALSE) { assert(false); }
   virtual Int_t    AutoParse(const char* cls);
   virtual void     ClearFileBusy() { assert(false); }
   virtual void     ClearStack() { assert(false); } // Delete existing temporary values
   virtual Bool_t   Declare(const char* code) { assert(false); }
   virtual void     EnableAutoLoading() { assert(false); }
   virtual void     EndOfLineAction() { assert(false); }
   virtual TClass  *GetClass(const std::type_info& typeinfo, Bool_t load) const { assert(false); }
   virtual Int_t    GetExitCode() const { assert(false); }
   virtual TEnv    *GetMapfile() const { return 0; }
   virtual Int_t    GetMore() const { assert(false); }
   virtual TClass  *GenerateTClass(const char *classname, Bool_t emulation, Bool_t silent = kFALSE);
   virtual TClass  *GenerateTClass(ClassInfo_t *classinfo, Bool_t silent = kFALSE) { assert(false); }
   virtual Int_t    GenerateDictionary(const char *classes, const char *includes = 0, const char *options = 0) { assert(false); }
   virtual char    *GetPrompt() { assert(false); }
   virtual const char *GetSharedLibs();
   virtual const char *GetClassSharedLibs(const char *cls);
   virtual const char *GetSharedLibDeps(const char *lib);
   virtual const char *GetIncludePath() { assert(false); }
   virtual const char *GetSTLIncludePath() const { return ""; }
   virtual TObjArray  *GetRootMapFiles() const { assert(false); }
   virtual void     Initialize() { assert(false); }
   virtual void     InspectMembers(TMemberInspector&, const void* obj, const TClass* cl, Bool_t isTransient) { assert(false); }
   virtual Bool_t   IsLoaded(const char *filename) const { assert(false); }
   virtual Int_t    Load(const char *filenam, Bool_t system = kFALSE);
   virtual void     LoadMacro(const char *filename, EErrorCode *error = 0) { assert(false); }
   virtual Int_t    LoadLibraryMap(const char *rootmapfile = 0);
   virtual Int_t    RescanLibraryMap() { assert(false); }
   virtual Int_t    ReloadAllSharedLibraryMaps() { assert(false); }
   virtual Int_t    UnloadAllSharedLibraryMaps() { assert(false); }
   virtual Int_t    UnloadLibraryMap(const char *library);
   virtual Long_t   ProcessLine(const char *line, EErrorCode *error = 0);
   virtual Long_t   ProcessLineSynch(const char *line, EErrorCode *error = 0);
   virtual void     PrintIntro() { assert(false); }
   virtual void     RegisterModule(const char* /*modulename*/,
                                   const char** /*headers*/,
                                   const char** /*includePaths*/,
                                   const char* /*payloadCode*/,
                                   const char* /*fwdDeclsCode*/,
                                   void (* /*triggerFunc*/)(),
                                   const FwdDeclArgsToKeepCollection_t& fwdDeclArgsToKeep,
                                   const char** classesHeaders);
   virtual void     RegisterTClassUpdate(TClass *oldcl,DictFuncPtr_t dict) { assert(false); }
   virtual void     UnRegisterTClassUpdate(const TClass *oldcl);
   virtual Int_t    SetClassSharedLibs(const char *cls, const char *libs) { assert(false); }
   virtual void     SetGetline(const char*(*getlineFunc)(const char* prompt),
                               void (*histaddFunc)(const char* line)) { assert(false); }
   virtual void     Reset() { assert(false); }
   virtual void     ResetAll() { assert(false); }
   virtual void     ResetGlobals();
   virtual void     ResetGlobalVar(void *obj) { assert(false); }
   virtual void     RewindDictionary() { assert(false); }
   virtual Int_t    DeleteGlobal(void *obj) { assert(false); }
   virtual Int_t    DeleteVariable(const char* name) { assert(false); }
   virtual void     SaveContext();
   virtual void     SaveGlobalsContext();
   virtual void     UpdateListOfGlobals() { assert(false); }
   virtual void     UpdateListOfGlobalFunctions() { assert(false); }
   virtual void     UpdateListOfTypes() { assert(false); }
   virtual void     SetClassInfo(TClass *cl, Bool_t reload = kFALSE);
   virtual Bool_t   CheckClassInfo(const char *name, Bool_t autoload, Bool_t isClassOrNamespaceOnly = kFALSE);
   virtual Bool_t   CheckClassTemplate(const char *name) { assert(false); }
   virtual Long_t   Calc(const char *line, EErrorCode* error = 0) { assert(false); }
   virtual void     CreateListOfBaseClasses(TClass *cl) const;
   virtual void     CreateListOfDataMembers(TClass *cl) const { assert(false); }
   virtual void     CreateListOfMethods(TClass *cl) const { assert(false); }
   virtual void     CreateListOfMethodArgs(TFunction *m) const { assert(false); }
   virtual void     UpdateListOfMethods(TClass *cl) const { assert(false); }
   virtual TString  GetMangledName(TClass *cl, const char *method, const char *params, Bool_t objectIsConst = kFALSE) { assert(false); }
   virtual TString  GetMangledNameWithPrototype(TClass *cl, const char *method, const char *proto, Bool_t objectIsConst = kFALSE, ROOT::EFunctionMatchMode /* mode */ = ROOT::kConversionMatch) { assert(false); }
   virtual void     GetInterpreterTypeName(const char *name, std::string &output, Bool_t full = kFALSE);
   virtual void    *GetInterfaceMethod(TClass *cl, const char *method, const char *params, Bool_t objectIsConst = kFALSE) { assert(false); }
   virtual void    *GetInterfaceMethodWithPrototype(TClass *cl, const char *method, const char *proto, Bool_t objectIsConst = kFALSE, ROOT::EFunctionMatchMode /* mode */ = ROOT::kConversionMatch) { assert(false); }
   virtual void     Execute(const char *function, const char *params, int *error = 0) { assert(false); }
   virtual void     Execute(TObject *obj, TClass *cl, const char *method, const char *params, int *error = 0) { assert(false); }
   virtual void     Execute(TObject *obj, TClass *cl, TMethod *method, TObjArray *params, int *error = 0) { assert(false); }
   virtual void     ExecuteWithArgsAndReturn(TMethod *method, void* address, const void* args[] = 0, int /*nargs*/ = 0, void* ret= 0) const { assert(false); }
   virtual Long_t   ExecuteMacro(const char *filename, EErrorCode *error = 0);
   virtual Bool_t   IsErrorMessagesEnabled() const { assert(false); }
   virtual Bool_t   SetErrorMessages(Bool_t enable = kTRUE) { assert(false); }
   virtual Bool_t   IsProcessLineLocked() const { assert(false); }
   virtual void     SetProcessLineLock(Bool_t lock = kTRUE) { assert(false); }
   virtual const char *TypeName(const char *s) { assert(false); }

   // core/meta helper functions.
   virtual EReturnType MethodCallReturnType(TFunction *func) const { assert(false); }
   virtual ULong64_t GetInterpreterStateMarker() const { assert(false); }

   typedef TDictionary::DeclId_t DeclId_t;
   virtual DeclId_t GetDeclId(CallFunc_t *info) const { assert(false); }
   virtual DeclId_t GetDeclId(ClassInfo_t *info) const { assert(false); }
   virtual DeclId_t GetDeclId(DataMemberInfo_t *info) const { assert(false); }
   virtual DeclId_t GetDeclId(FuncTempInfo_t *info) const { assert(false); }
   virtual DeclId_t GetDeclId(MethodInfo_t *info) const { assert(false); }
   virtual DeclId_t GetDeclId(TypedefInfo_t *info) const { assert(false); }

   virtual void SetDeclAttr(DeclId_t, const char* /* attribute */) { assert(false); }

   virtual DeclId_t GetDataMember(ClassInfo_t *cl, const char *name) const { assert(false); }
   virtual DeclId_t GetDataMemberAtAddr(const void *addr) const { assert(false); }
   virtual DeclId_t GetDataMemberWithValue(const void *ptrvalue) const { assert(false); }
   virtual DeclId_t GetEnum(TClass *cl, const char *name) const { assert(false); }
   virtual TEnum*   CreateEnum(void *VD, TClass *cl) const { assert(false); }
   virtual void     UpdateEnumConstants(TEnum* enumObj, TClass* cl) const { assert(false); }
   virtual void     LoadEnums(TListOfEnums& cl) const { assert(false); }
   virtual DeclId_t GetFunction(ClassInfo_t *cl, const char *funcname) { assert(false); }
   virtual DeclId_t GetFunctionWithPrototype(ClassInfo_t *cl, const char* method, const char* proto, Bool_t objectIsConst = kFALSE, ROOT::EFunctionMatchMode mode = ROOT::kConversionMatch) { assert(false); }
   virtual DeclId_t GetFunctionWithValues(ClassInfo_t *cl, const char* method, const char* params, Bool_t objectIsConst = kFALSE) { assert(false); }
   virtual DeclId_t GetFunctionTemplate(ClassInfo_t *cl, const char *funcname) { assert(false); }
   virtual void     GetFunctionOverloads(ClassInfo_t *cl, const char *funcname, std::vector<DeclId_t>& res) const { assert(false); }
   virtual void     LoadFunctionTemplates(TClass* cl) const { assert(false); }

   // CallFunc interface
   virtual void   CallFunc_SetArg(CallFunc_t * /*func */, Long_t /* param */) const { assert(false); }
   virtual void   CallFunc_SetArg(CallFunc_t * /*func */, ULong_t /* param */) const { assert(false); }
   virtual void   CallFunc_SetArg(CallFunc_t * /* func */, Float_t /* param */) const { assert(false); }
   virtual void   CallFunc_SetArg(CallFunc_t * /* func */, Double_t /* param */) const { assert(false); }
   virtual void   CallFunc_SetArg(CallFunc_t * /* func */, Long64_t /* param */) const { assert(false); }
   virtual void   CallFunc_SetArg(CallFunc_t * /* func */, ULong64_t /* param */) const { assert(false); }

   virtual void   CallFunc_SetFuncProto(CallFunc_t* func, ClassInfo_t* info, const char* method, const std::vector<TypeInfo_t*> &proto, Long_t* Offset, ROOT::EFunctionMatchMode mode = ROOT::kConversionMatch) const { assert(false); }
   virtual void   CallFunc_SetFuncProto(CallFunc_t* func, ClassInfo_t* info, const char* method, const std::vector<TypeInfo_t*> &proto, bool objectIsConst, Long_t* Offset, ROOT::EFunctionMatchMode mode = ROOT::kConversionMatch) const { assert(false); }


   // ClassInfo interface
   virtual Bool_t ClassInfo_Contains(ClassInfo_t *info, DeclId_t decl) const { assert(false); }
   virtual ClassInfo_t  *ClassInfo_Factory(Bool_t /*all*/ = kTRUE) const { assert(false); }
   virtual ClassInfo_t  *ClassInfo_Factory(ClassInfo_t * /* cl */) const { assert(false); }
   virtual ClassInfo_t  *ClassInfo_Factory(const char * /* name */) const { assert(false); }

   virtual ClassInfo_t *BaseClassInfo_ClassInfo(BaseClassInfo_t * /* bcinfo */) const { assert(false); }

   // Function Template interface
   virtual void   FuncTempInfo_Delete(FuncTempInfo_t * /* ft_info */) const { assert(false); }
   virtual FuncTempInfo_t  *FuncTempInfo_Factory(DeclId_t declid) const { assert(false); }
   virtual FuncTempInfo_t  *FuncTempInfo_FactoryCopy(FuncTempInfo_t * /* ft_info */) const { assert(false); }
   virtual Bool_t FuncTempInfo_IsValid(FuncTempInfo_t * /* ft_info */) const { assert(false); }
   virtual UInt_t FuncTempInfo_TemplateNargs(FuncTempInfo_t * /* ft_info */) const { assert(false); }
   virtual UInt_t FuncTempInfo_TemplateMinReqArgs(FuncTempInfo_t * /* ft_info */) const { assert(false); }
   virtual Long_t FuncTempInfo_Property(FuncTempInfo_t * /* ft_info */) const { assert(false); }
   virtual void FuncTempInfo_Name(FuncTempInfo_t * /* ft_info */, TString &name) const { assert(false); }
   virtual void FuncTempInfo_Title(FuncTempInfo_t * /* ft_info */, TString &title) const { assert(false); }

   // MethodInfo interface
   virtual MethodInfo_t  *MethodInfo_Factory(DeclId_t declid) const { assert(false); }
   virtual Long_t MethodInfo_Property(MethodInfo_t * /* minfo */) const { assert(false); }
   virtual Long_t MethodInfo_ExtraProperty(MethodInfo_t * /* minfo */) const { assert(false); }
   virtual EReturnType MethodInfo_MethodCallReturnType(MethodInfo_t* minfo) const { assert(false); }

   // MethodArgInfo interface
   virtual std::string MethodArgInfo_TypeNormalizedName(MethodArgInfo_t * /* marginfo */) const { assert(false); }

   virtual DataMemberInfo_t  *DataMemberInfo_Factory(DeclId_t declid, ClassInfo_t* clinfo) const { assert(false); }
};

TCxx::~TCxx() {}

#endif
