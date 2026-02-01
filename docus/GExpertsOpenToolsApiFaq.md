---
created: 2025-12-29T12:28:00 (UTC +01:00)
tags: []
source: https://www.gexperts.org/open-tools-api-faq/
author: 
---

# Open Tools API FAQ | GExperts

> ## Excerpt
> If you have additions or corrections, please contact me. But, please do not send me questions about how to use the Open Tools API – instead, use the resources listed below.

---
### Article Index

-   [What is the Open Tools API?](https://www.gexperts.org/open-tools-api-faq/#whatis)
-   [Where is the Open Tools API documented?](https://www.gexperts.org/open-tools-api-faq/#docs)
-   [Where can I get help with my Open Tools API questions?](https://www.gexperts.org/open-tools-api-faq/#help)
-   [What is the “old” OTA and what is the “new” OTA? Which one should I use?](https://www.gexperts.org/open-tools-api-faq/#oldnew)
-   [Where can I get a simple wizard/expert to customize?](https://www.gexperts.org/open-tools-api-faq/#sample)
-   [Can I create wizards in C++Builder?](https://www.gexperts.org/open-tools-api-faq/#cpp)
-   [Can I install a Delphi-created wizard into C++Builder?](https://www.gexperts.org/open-tools-api-faq/#dincpp)
-   [Should I ever call Release on an interface obtained from the IDE?](https://www.gexperts.org/open-tools-api-faq/#release)
-   [How can I add published properties to a TForm descendent?](https://www.gexperts.org/open-tools-api-faq/#published)
-   [How do I obtain the current project (IOTAProject) interface?](https://www.gexperts.org/open-tools-api-faq/#projectintf)
-   [How do I obtain the current project group (IOTAProjectGroup) interface?](https://www.gexperts.org/open-tools-api-faq/#projectgroup)
-   [How can I obtain the IOTAProjectResource interface for a given project?](https://www.gexperts.org/open-tools-api-faq/#resource)
-   [How can I get a list of all installed components?](https://www.gexperts.org/open-tools-api-faq/#components)
-   [Is there any OTA support for creating type libraries or controlling the type library editor?](https://www.gexperts.org/open-tools-api-faq/#typelib)
-   [Is there any OTA support for parsing a source file or obtaining Code Insight information?](https://www.gexperts.org/open-tools-api-faq/#parse)
-   [Should I compile my wizard as a DLL or a Package?](https://www.gexperts.org/open-tools-api-faq/#dlldpk)
-   [Why does my wizard have to dynamically link to the VCL/DesignIde packages?](https://www.gexperts.org/open-tools-api-faq/#link)
-   [How do I get a hold of the designer for a DataModule?](https://www.gexperts.org/open-tools-api-faq/#dmdesigner)
-   [How do a I get a reference to an IOTAXxxx interface?](https://www.gexperts.org/open-tools-api-faq/#intfref)
-   [How can I debug a DLL wizard?](https://www.gexperts.org/open-tools-api-faq/#debugdll)
-   [How can I debug a package wizard?](https://www.gexperts.org/open-tools-api-faq/#debugbpl)
-   [How do I implement an IDE notifier (IOTAIDENotifier)?](https://www.gexperts.org/open-tools-api-faq/#idenotifier)
-   [How do I implement an editor notifier (IOTAEditorNotifier)?](https://www.gexperts.org/open-tools-api-faq/#editornotifier)
-   [How do I implement a form notifier (IOTAFormNotifier)?](https://www.gexperts.org/open-tools-api-faq/#formnotifier)
-   [How can I get notified when a source file has changed?](https://www.gexperts.org/open-tools-api-faq/#sourcechange)
-   [How can I get notified when a form designer or component is selected?](https://www.gexperts.org/open-tools-api-faq/#selected)
-   [How can I add a menu item to the IDE’s main menu?](https://www.gexperts.org/open-tools-api-faq/#menuitem)
-   [How can I add a shortcut to my main menu item?](https://www.gexperts.org/open-tools-api-faq/#shortcut)
-   [How can I paint the palette bitmap for a specific component?](https://www.gexperts.org/open-tools-api-faq/#compbitmap)
-   [How do I implement a module creator (IOTAModuleCreator/IOTAFormWizard)?](https://www.gexperts.org/open-tools-api-faq/#modulecreator)
-   [How do I implement a project creator (IOTAProjectCreator)?](https://www.gexperts.org/open-tools-api-faq/#projectcreator)
-   [How can I save/load values to a project’s desktop settings (.dsk) file?](https://www.gexperts.org/open-tools-api-faq/#dsk)
-   [How can I add menu items to the code editor’s popup menu?](https://www.gexperts.org/open-tools-api-faq/#editorcontext)
-   [How does the native OTA deal with UNICODE strings in the editor?](https://www.gexperts.org/open-tools-api-faq/#unicode)
-   [How can I iterate over all units/forms in a project?](https://www.gexperts.org/open-tools-api-faq/#iterateunits)
-   [How can I do custom painting or drawing (colors, lines, etc.) in the IDE code editor?](https://www.gexperts.org/open-tools-api-faq/#custompaint)
-   [How can I publish a property of type T\[Custom\]Form?](https://www.gexperts.org/open-tools-api-faq/#publishedform)
-   [How can I create a form that docks into the IDE like the Object Inspector?](https://www.gexperts.org/open-tools-api-faq/#dockform)
-   [How can I obtain the currently active form editor (IOTAFormEditor)?](https://www.gexperts.org/open-tools-api-faq/#formeditor)
-   [How can I obtain the current form designer interface (IFormDesigner)?](https://www.gexperts.org/open-tools-api-faq/#formdesigner)
-   [How can I get a form editor from a module interface?](https://www.gexperts.org/open-tools-api-faq/#formeditorintf)
-   [Is there a way to determine if the user is editing a form or working in the code editor?](https://www.gexperts.org/open-tools-api-faq/#editororform)
-   [How can I obtain the Name property of a form?](https://www.gexperts.org/open-tools-api-faq/#nameform)
-   [How can I create a method and then assign an event handler at design-time?](https://www.gexperts.org/open-tools-api-faq/#eventhandler)
-   [How can I force the code editor to show a specific file tab?](https://www.gexperts.org/open-tools-api-faq/#editortab)
-   [How can I determine the filename of the binary/exe/dll/bpl/ocx/etc. generated by a compile or build?](https://www.gexperts.org/open-tools-api-faq/#compiledbin)
-   [Known bugs in the Delphi 2007 Open Tools API (most also apply to earlier releases):](https://www.gexperts.org/open-tools-api-faq/#BD2007)
-   [Known bugs in the BDS 2006 Open Tools API (most also apply to earlier releases):](https://www.gexperts.org/open-tools-api-faq/#BBDS2006)
-   [Known bugs in the Delphi 2005 Open Tools API:](https://www.gexperts.org/open-tools-api-faq/#BD2005)
-   [Known bugs in the Delphi 7 Open Tools API (most also apply to Delphi/BCB 6):](https://www.gexperts.org/open-tools-api-faq/#BD7)
-   [Known bugs in the Delphi 6 Open Tools API (most also apply to Delphi/BCB 5):](https://www.gexperts.org/open-tools-api-faq/#BD6)
-   [Known bugs in the C++Builder 5.01 Open Tools API:](https://www.gexperts.org/open-tools-api-faq/#BC5)
-   [Known bugs in the Delphi 5.01 Open Tools API:](https://www.gexperts.org/open-tools-api-faq/#BD5)

If you have additions or corrections, please [contact](https://www.gexperts.org/contact/) me. But, please do not send me questions about how to use the Open Tools API – instead, use the resources listed below.

## What is the Open Tools API?

The Open Tools API (OTA) is a set of interfaces that allow developers to add features to the BDS, Delphi, and C++Builder IDEs. These additions are called wizards or experts. Wizards can use the OTA interfaces to modify the IDE, obtain information about the IDE’s state, and receive notification of important events. To create wizards, you should first get an IDE version that includes the VCL source (Professional, Enterprise, Architect, etc.) since these versions also include the interface definitions in ToolsAPI.pas that will make your programming easier.

## Where is the Open Tools API documented?

In the latest help update for Delphi 6, in C++Builder 6, and in Delphi 7 the OTA is fairly well documented. Open the \*iota.hlp file and look at the index there for details. For writing .NET addins in C#Builder and Delphi for .NET, also see [my article](http://edn.embarcadero.com/article/30194) on the EDN and the two [IDE integration packages](http://edn.embarcadero.com/article/31918) provided by CodeGear/Borland. Sadly, most of the official OTA documentation was removed and is not present anymore in Delphi 8-2007.

## Where can I get help with my Open Tools API questions?

**\\Source\\ToolsAPI\\ToolsAPI.pas:**  
A good place to learn about the Open Tools API is is the ToolsAPI.pas unit and the related files in that directory such as PaletteAPI.pas, StructureViewAPI.pas, and CodeTemplateAPI.pas. If you don’t have any of those files, try reinstalling the IDE including the source code option, or maybe you need to upgrade to a higher-end IDE edition that includes the source files (Professional, Enterprise, Architect, etc.). All of the OTA interfaces are defined in those files, and many of them have comments about their purpose and usage.

**Newsgroup Search Engines:  
**There are several free web services that allow you to search for answers to previously asked questions in the Open Tools API newsgroup. I recommend you search at least one of these before posting, as it generally gives multiple answers to the most common questions. Try one of the following:

| Search Site | Newsgroups | Date Range | Search Features | Speed |
| --- | --- | --- | --- | --- |
| [Google Groups](http://groups.google.com/) | All | May 1981 – Now | Good | Fast |
| [Code News Fast](http://codenewsfast.com/) | CodeGear/Borland | Oct. 1997 – Now | Moderate | Moderate |

**The Open Tools API Newsgroup**:  
Embarcadero runs a discussion forum that has an Open Tools API group in it. Before posting, please check the newsgroup search engines above for answers to your questions. You can access the forum on the web at [https://forums.embarcadero.com/](https://forums.embarcadero.com/) under Delphi, Open Tools API or using an NNTP newsgroup reader via [these instructions](http://edn.embarcadero.com/article/38435).

**Example Code:**

-   [Torry’s Delphi Pages](http://torry.net/)
-   [Delphi Super Page (abandoned?)](http://delphi.icm.edu.pl/)

**Other Web Sites:**

-   [Ray Lischner’s Open Tools Resources](http://www.tempest-sw.com/opentools/) – Ray’s web site is a bit out-of-date and only covers the interfaces through Delphi 3/4, but might still be useful to some people.

## What is the “old” OTA and what is the “new” OTA? Which one should I use?

The “old” Open Tools API (OTA) was the preferred method for addins to interface with the IDE in Delphi 3 and older and was class-based. The “new” OTA is present in Delphi/BCB 4 or later and is interface-based. This FAQ only covers the new OTA, which consists mainly of the ToolsAPI.pas unit. Starting with Delphi 8 or greater, you will find a few more files that define the OTA such as PaletteAPI.pas, StructureViewAPI.pas, CodeTemplateAPI.pas, FileHistoryAPI.pas, DesignerTypes.pas and PropInspAPI.pas. The older OTA is depreciated and should no longer be used except to maintain compatibility with older IDE versions. Support for the old OTA will be completely dropped in a future version of Delphi, and existing bugs in it are not being fixed. The old Open Tools API consists of the following units: ExptIntf, FileIntf, IStreams, ToolIntf, VcsIntf, VirtIntf.

## Where can I get a simple wizard/expert to customize?

Here is the Pascal source for the simplest [“Hello World!”](http://www.gexperts.org/examples/HelloWorldWizard.zip) wizard using the Open Tools API. Just compile and install this package (DPK) into the IDE, and try out the new menu item on the Help menu. This example was written and tested in Delphi XE but should work in several other recent IDE versions. Older IDE versions such as Delphi 5/6/7 and earlier will require changes to the package list in the DPK.

## Can I create wizards in C++Builder?

Yes. The Open Tools API was originally designed with Delphi in mind, so wizards might be easier to create in Delphi, but C++Builder works fine to create native code IDE addins.

## Can I install a Delphi-created wizard into C++Builder?

Yes, GExperts is one example of an expert written in Delphi that can be compiled and installed into C++Builder.

## Should I ever call Release on an interface obtained from the IDE?

It is not necessary to call Release on an IDE interface obtained via the Open Tools API. The interfaces are reference counted for you, and the associated memory will be freed as soon as all interface references go out of scope. Note that you can force the IDE to release an interface by setting all references to nil.

## How can I add published properties to a TForm descendent?

-   Add published properties to a regular TForm
-   Add the form to the Object Repository (Project menu)
-   Add the form to an existing design time package (such as Borland User Components) or to a new design-time package.
-   Add DsgnIntf/DesignIntf to the implementation uses clause of a unit in the package, and add a Register procedure as follows:

<table><tbody><tr><td><p>1</p><p>2</p><p>3</p><p>4</p></td><td><div><p><code>procedure</code> <code>Register;</code></p><p><code>begin</code></p><p><code>&nbsp;&nbsp;</code><code>RegisterCustomModule(TMyForm, TCustomModule);</code></p><p><code>end</code><code>;</code></p></div></td></tr></tbody></table>

-   Finally, inherit from your form in the repository inside a project and the new published properties will show up. Remember to not try to link to the new designtime package when building your deployable application.

There is also a much more complex method involving writing a module creation expert, a repository expert, and using CreateModuleEx and different streams, but is much more error-prone and for most people, has no advantages.

Note that the IDE will not allow you to add both published properties and components to a custom module at the same time. The workaround is to create a form with your custom properties in a package, and then have a descendent form in the repository which adds the components you want there by default.

## How do I obtain the current project (IOTAProject) interface?

Starting with Delphi 7, you can use the function GetActiveProject. For previous releases, you can iterate through all of the modules to find the project group and then get that group’s active project:

<table><tbody><tr><td><p>1</p><p>2</p><p>3</p><p>4</p><p>5</p><p>6</p><p>7</p><p>8</p><p>9</p><p>10</p><p>11</p><p>12</p><p>13</p><p>14</p><p>15</p><p>16</p><p>17</p><p>18</p><p>19</p><p>20</p><p>21</p><p>22</p><p>23</p><p>24</p><p>25</p></td><td><div><p><code>function</code> <code>GetCurrentProject: IOTAProject;</code></p><p><code>var</code></p><p><code>&nbsp;&nbsp;</code><code>ModServices: IOTAModuleServices;</code></p><p><code>&nbsp;&nbsp;</code><code>Module: IOTAModule;</code></p><p><code>&nbsp;&nbsp;</code><code>Project: IOTAProject;</code></p><p><code>&nbsp;&nbsp;</code><code>ProjectGroup: IOTAProjectGroup;</code></p><p><code>&nbsp;&nbsp;</code><code>i: </code><code>Integer</code><code>;</code></p><p><code>begin</code></p><p><code>&nbsp;&nbsp;</code><code>Result := </code><code>nil</code><code>;</code></p><p><code>&nbsp;&nbsp;</code><code>ModServices := BorlandIDEServices </code><code>as</code> <code>IOTAModuleServices;</code></p><p><code>&nbsp;&nbsp;</code><code>for</code> <code>i := </code><code>0</code> <code>to</code> <code>ModServices</code><code>.</code><code>ModuleCount - </code><code>1</code> <code>do</code></p><p><code>&nbsp;&nbsp;</code><code>begin</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>Module := ModServices</code><code>.</code><code>Modules[i];</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>if</code> <code>Supports(Module, IOTAProjectGroup, ProjectGroup) </code><code>then</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>begin</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</code><code>Result := ProjectGroup</code><code>.</code><code>ActiveProject;</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</code><code>Exit;</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>end</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>else</code> <code>if</code> <code>Supports(Module, IOTAProject, Project) </code><code>then</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>begin</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</code><code>if</code> <code>Result = </code><code>nil</code> <code>then</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</code><code>Result := Project;</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>end</code><code>;</code></p><p><code>&nbsp;&nbsp;</code><code>end</code><code>;</code></p><p><code>end</code><code>;</code></p></div></td></tr></tbody></table>

## How do I obtain the current project group (IOTAProjectGroup) interface?

Starting with Delphi 7, you can use the GetActiveProjectGroup function. For earlier releases, you can iterate through all of the modules to find the one that implements IOTAProjectGroup:

<table><tbody><tr><td><p>1</p><p>2</p><p>3</p><p>4</p><p>5</p><p>6</p><p>7</p><p>8</p><p>9</p><p>10</p><p>11</p><p>12</p><p>13</p><p>14</p><p>15</p><p>16</p><p>17</p><p>18</p><p>19</p></td><td><div><p><code>function</code> <code>GetCurrentProjectGroup: IOTAProjectGroup;</code></p><p><code>var</code></p><p><code>&nbsp;&nbsp;</code><code>ModServices: IOTAModuleServices;</code></p><p><code>&nbsp;&nbsp;</code><code>ProjectGroup: IOTAProjectGroup;</code></p><p><code>&nbsp;&nbsp;</code><code>Module: IOTAModule;</code></p><p><code>&nbsp;&nbsp;</code><code>i: </code><code>Integer</code><code>;</code></p><p><code>begin</code></p><p><code>&nbsp;&nbsp;</code><code>Result := </code><code>nil</code><code>;</code></p><p><code>&nbsp;&nbsp;</code><code>ModServices := BorlandIDEServices </code><code>as</code> <code>IOTAModuleServices;</code></p><p><code>&nbsp;&nbsp;</code><code>for</code> <code>i := </code><code>0</code> <code>to</code> <code>ModServices</code><code>.</code><code>ModuleCount - </code><code>1</code> <code>do</code></p><p><code>&nbsp;&nbsp;</code><code>begin</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>Module := ModServices</code><code>.</code><code>Modules[i];</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>if</code> <code>Supports(Module, IOTAProjectGroup, ProjectGroup) </code><code>then</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>begin</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</code><code>Result := ProjectGroup;</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</code><code>Break;</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>end</code><code>;</code></p><p><code>&nbsp;&nbsp;</code><code>end</code><code>;</code></p><p><code>end</code><code>;</code></p></div></td></tr></tbody></table>

## How can I obtain the IOTAProjectResource interface for a given project?

Note that there is a [bug in Delphi 2005/2006](http://qc.embarcadero.com/wc/qcmain.aspx?d=15657) that may prevent this from working.

<table><tbody><tr><td><p>1</p><p>2</p><p>3</p><p>4</p><p>5</p><p>6</p><p>7</p><p>8</p><p>9</p><p>10</p><p>11</p><p>12</p><p>13</p></td><td><div><p><code>function</code> <code>GetProjectResource(Project: IOTAProject): IOTAProjectResource;</code></p><p><code>var</code></p><p><code>&nbsp;&nbsp;</code><code>i: </code><code>Integer</code><code>;</code></p><p><code>&nbsp;&nbsp;</code><code>Editor: IOTAEditor;</code></p><p><code>begin</code></p><p><code>&nbsp;&nbsp;</code><code>Result := </code><code>nil</code><code>;</code></p><p><code>&nbsp;&nbsp;</code><code>for</code> <code>i:= </code><code>0</code> <code>to</code> <code>(Project</code><code>.</code><code>GetModuleFileCount - </code><code>1</code><code>) </code><code>do</code></p><p><code>&nbsp;&nbsp;</code><code>begin</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>Editor := Project</code><code>.</code><code>GetModuleFileEditor(i);</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>if</code> <code>Supports(Editor, IOTAProjectResource, Result) </code><code>then</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</code><code>Break;</code></p><p><code>&nbsp;&nbsp;</code><code>end</code><code>;</code></p><p><code>end</code><code>;</code></p></div></td></tr></tbody></table>

## How can I get a list of all installed components?

See IOTAPackageServices.GetComponentName in ToolsAPI.pas.

## Is there any OTA support for creating type libraries or controlling the type library editor?

If you look at IOTATypeLibEditor and IOTATypeLibModule, you’ll see there might be internal plans to add some support, but it isn’t implemented yet. For now those interfaces can only be used to see if a file is a type library or not. Apparently, COM provides some services to create type libraries.

## Is there any OTA support for parsing a source file or obtaining Code Insight information?

C#Builder, Delphi 8+, and BDS support obtaining the .NET CodeDom for C# and Delphi code using IOTACodeDomProvider, but older IDEs do not expose unit structure details or Code Insight information such as method parameter lists, symbol declaration locations, class members, and symbol table information. As a result, you will need to parse the source yourself or use an existing language parser such as those at [Torry’s Delphi Pages](http://torry.net/) (search for mwDelPar or mwPasPar, for examples). Starting with Delphi 7, you can implement your own code completion and parameter hints via the IOTACodeInsight\* interfaces, but the source parsing is still up to you.

## Should I compile my wizard as a DLL or a Package?

Packages are easier to load and unload without restarting the IDE (and hence easier to debug), but they can create unit naming conflicts in the IDE. Conflicts happen when the name a wizard’s unit matches the name of a unit in another loaded design-time package. In this case, both packages can not be loaded at the same time. The recommended workaround is to prefix all of your unit names with a “unique” prefix. GExperts, for example, uses “GX\_” as the name prefix for its units.

## Why does my wizard have to dynamically link to the VCL/DesignIde packages?

If you want access to a useful BorlandIDEServices global variable from ToolsAPI.pas, you must compile your wizard linking to the DesignIde package (in Deplhi 6+) or the VCL package (in Delphi 4/5). See the Packages tab in the Project Options dialog for help on compiling with packages.

## How do I get a hold of the designer for a DataModule?

The owner of the datamodule at design-time is a TCustomForm which has a Designer property.

## How do a I get a reference to an IOTAXxxx interface?

In general, just search ToolsAPI.pas for a method that returns the interface type you are looking for. But, sometimes things are a little trickier, and you have to use Supports or QueryInterface to find what you want:

| Interface | Obtained From |
| --- | --- |
| INTAComponent | IOTAComponent |
| INTAFormEditor | IOTAFormEditor |
| IFormDesigner | INTAFormEditor |
| IOTAKeyboardDiagnostics | BorlandIDEServices |
| IOTAEditActions | IOTAEditView |

## How can I debug a DLL wizard?

1.  Exit your IDE
2.  Remove any registry entries which load the expert DLL into your IDE. Look in HKEY\_CURRENT\_USER\\Software\\Borland\\Delphi\\X.0\\Experts.
3.  Start your IDE, and verify the expert is not loaded.
4.  Compile your expert DLL. In the project options, be sure to turn on debug information, stack frames, reference info, etc.
5.  Turn optimizations off.
6.  Re-register the DLL with the IDE by adding an entry to HKEY\_CURRENT\_USER\\Software\\Borland\\Delphi\\X.0\\Experts.
7.  Select Run, Parameters from the IDE menu. Enter the IDE’s executable as the host application for your DLL.
8.  Run the host application (F9), and another copy of your IDE should appear with the expert loaded.
9.  You can now debug the DLL as it were a normal program (watches, breakpoints, inspections, tooltip evaluation, etc.).
10.  Note that package debugging does not work well in Delphi 4 and BCB 4. Both will lockup fairly often when debugging DLLs and packages. Later releases should work better.

## How can I debug a package wizard?

1.  In the project options for your package, turn on debug information, stack frames, reference info, etc. Turn optimizations off.
2.  Uncheck your package in the Project Options Packages tab, if necessary.
3.  Build your package (don’t install it).
4.  Select Run, Parameters from the IDE menu. Enter the IDE’s executable as the host application for your package.
5.  Run the host application (F9), and another copy of your IDE should appear.
6.  In the second copy of the IDE, open up the Project Options and load your expert package into the IDE.
7.  You can now debug the package as it were a normal program (watches, breakpoints, inspections, tooltip evaluation, etc.).
8.  Note that package debugging does not work well in Delphi 4 and BCB 4. Both will lockup fairly often when debugging DLLs and packages. Later releases should work better.

## How do I implement an IDE notifier (IOTAIDENotifier)?

Create an object that implements all of the IOTAIDENotifier and descendent interface methods. Then register the notifier using IOTAServices.AddNotifier and watch for notification callbacks from the IDE. Be sure to call IOTAServices.RemoveNotifier when you are done. Here is a Delphi 5/6 example IOTAIDENotifier.

## How do I implement an editor notifier (IOTAEditorNotifier)?

Declare something similar to this:

<table><tbody><tr><td><p>1</p><p>2</p><p>3</p><p>4</p><p>5</p><p>6</p></td><td><div><p><code>TTestEditorNotifier = </code><code>class</code><code>(TNotifierObject, IOTAEditorNotifier)</code></p><p><code>public</code></p><p><code>&nbsp;&nbsp;</code><code>procedure</code> <code>Destroyed; override;</code></p><p><code>&nbsp;&nbsp;</code><code>procedure</code> <code>ViewActivated(</code><code>const</code> <code>View: IOTAEditView);</code></p><p><code>&nbsp;&nbsp;</code><code>procedure</code> <code>ViewNotification(</code><code>const</code> <code>View: IOTAEditView; Operation: TOperation);</code></p><p><code>end</code><code>;</code></p></div></td></tr></tbody></table>

Override any of the other IOTANotifier methods you need and add the notifier using IOTASourceEditor.AddNotifier. In the Destroyed notification remove the notifier using IOTASourceEditor.RemoveNotifier and the index returned from AddNotifier. Here is a [sample notifier package](http://www.gexperts.org/examples/IdeNotifier.pas) that works in BDS 2006.

## How do I implement a form notifier (IOTAFormNotifier)?

Declare something like this:

<table><tbody><tr><td><p>1</p><p>2</p><p>3</p><p>4</p><p>5</p><p>6</p><p>7</p></td><td><div><p><code>TMyFormNotifier = </code><code>class</code><code>(TNotifierObject, IOTANotifier, IOTAFormNotifier)</code></p><p><code>protected</code></p><p><code>&nbsp;&nbsp;</code><code>procedure</code> <code>FormActivated;</code></p><p><code>&nbsp;&nbsp;</code><code>procedure</code> <code>FormSaving;</code></p><p><code>&nbsp;&nbsp;</code><code>procedure</code> <code>ComponentRenamed(ComponentHandle: TOTAHandle;</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</code><code>const</code> <code>OldName, NewName: </code><code>string</code><code>);</code></p><p><code>end</code><code>;</code></p></div></td></tr></tbody></table>

Implement all of the above methods, even if they are blank. Finally, add your notifier using IOTAModule.GetModuleFileEditor(0).AddNotifier. Note that in Delphi 5, form notifiers won’t actually fire notifications for BeforeSave or AfterSave (use a module notifier for this). It should fire the notifications in the declaration above, as well as Destroyed and Modified from IOTANotifier.

## How can I get notified when a source file has changed?

Starting in Delphi 6, IOTAEditorNotifier works for this. In Delphi 4/5 IOTAEditorNotifier never fires, so instead, attach a module notifier using IOTAModule.AddNotifier and watch for IOTAModuleNotifier.Modified.

## How can I get notified when a form designer or component is selected?

When a form is activated, IOTAFormNotifier.FormActivated fires. If you are willing to add a notifier to every open form, this event will provide you with direct notifications. If you would rather not install a notifier for every open form, try using IDesignNotification.SelectionChanged. You will need to register your IDesignNotification interface with the IDE by calling RegisterDesignNotification and check the active form in each SelectionChanged callback.

Use INTAServices.GetMainMenu to obtain a reference to the IDE’s TMainMenu component. Iterate through all of the top-level menu items and find the parent menu item you want to add a menu item to. Then, use MyMenuItem.Insert() to add the menu item. GExperts has an IDE menu item expert that shows all IDE main menu items and their names. To handle selection of your menu item and associate an icon with it, will need to add an action to the main IDE action list, add an image to the IDE’s image list, and set the action’s ImageIndex and OnExecute properties. See INTAServices40 for the related methods. You may also find this tutorial (broken link?) by Miha Remec useful.

## How can I add a shortcut to my main menu item?

In Delphi 5+, you should register a shortcut for your menu item using the keybinding interfaces:

-   Implement IOTAKeyboardBinding and make sure GetBindingType returns btPartial
-   Add your binding to the IDE using IOTAKeyboardServices.AddKeyboardBinding
-   In the IOTAKeyboardBinding.BindKeyboard callback, use the passed in IOTAKeyBindingServices reference to call BindingServices.AddKeyBinding for each menu item, as described below:
    -   Pass in a TKeyBindingProc type procedure callback method for when your shortcuts are pressed procedure Callback(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
    -   Pass in the menu item’s name as the last parameter (the ill named “HotKey” in Delphi 5). The call should look similar to this:
        
        <table><tbody><tr><td><p>1</p><p>2</p></td><td><div><p><code>AddKeyBinding([ShortCut(Ord(</code><code>'G'</code><code>), [ssCtrl])], Callback,</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>nil</code><code>, </code><code>0</code><code>, </code><code>''</code><code>, </code><code>'MyMenuItem'</code><code>);</code></p></div></td></tr></tbody></table>
        

In Delphi 4, you will need to wait a few seconds after the IDE starts and set the menu item’s ShortCut property. A timer works well to create the delay. Here is a [sample keybinding](http://www.gexperts.org/examples/KeyBinding.pas) unit that should work in Delphi 6 – Delphi 2007 to get you started. You will need to customize it to handle your menu item, as described above.

## How can I paint the palette bitmap for a specific component?

In Delphi 4/5 you need to use the LibIntf unit, which is unsupported and undocumented, but try:

<table><tbody><tr><td><p>1</p></td><td><div><p><code>LibIntf</code><code>.</code><code>DelphiIDE</code><code>.</code><code>GetPaletteItem(GetClass(</code><code>'TButton'</code><code>)).Paint</code></p></div></td></tr></tbody></table>

In Delphi 6+ you can try to load the component bitmaps from the .bpl package resources manually (by name) or try using the ComponentDesigner unit similar to this:

<table><tbody><tr><td><p>1</p><p>2</p><p>3</p><p>4</p><p>5</p><p>6</p><p>7</p><p>8</p><p>9</p></td><td><div><p><code>var</code></p><p><code>&nbsp;&nbsp;</code><code>PaletteItem: IPaletteItem;</code></p><p><code>&nbsp;&nbsp;</code><code>PalettePaint: IPalettePaint;</code></p><p><code>begin</code></p><p><code>&nbsp;&nbsp;</code><code>with</code> <code>ComponentDesigner</code><code>.</code><code>ActiveDesigner</code><code>.</code><code>Environment </code><code>do</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>PaletteItem := GetPaletteItem(</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</code><code>TComponentClass(FindClass(</code><code>'TButton'</code><code>))) </code><code>as</code> <code>IPaletteItem;</code></p><p><code>&nbsp;&nbsp;</code><code>PalettePaint :=&nbsp; PaletteItem </code><code>as</code> <code>IPalettePaint;</code></p><p><code>&nbsp;&nbsp;</code><code>PalettePaint</code><code>.</code><code>Paint(ACanvas, X, Y);</code></p></div></td></tr></tbody></table>

## How do I implement a module creator (IOTAModuleCreator/IOTAFormWizard)?

Descend from TInterfacedObject and implement all of the methods in IOTACreator and IOTAModuleCreator as follows:

<table><tbody><tr><td><p>1</p></td><td><div><p><code>TGxModuleCreator = </code><code>class</code><code>(TInterfacedObject, IOTACreator, IOTAModuleCreator)</code></p></div></td></tr></tbody></table>

Here is [sample code](http://www.gexperts.org/examples/GXModuleCreator.pas) for a Delphi 6-2007 module creator that resides in the File, New, Other repository screen by implementing IOTARepositoryWizard and the other required interfaces.

## How do I implement a project creator (IOTAProjectCreator)?

Descend from TInterfacedObject and implement all of the methods in IOTACreator and IOTAProjectCreator as follows:

<table><tbody><tr><td><p>1</p></td><td><div><p><code>TGxProjectCreator = </code><code>class</code><code>(TInterfacedObject, IOTACreator, IOTAProjectCreator)</code></p></div></td></tr></tbody></table>

Here is [sample code](http://www.gexperts.org/examples/ProjectCreator.pas) for a project creator that installs itself into the Help menu.

## How can I save/load values to a project’s desktop settings (.dsk) file?

In the FileNotification method of an installed IOTAIDENotifier, check for the ofnProjectDesktopLoad and ofnProjectDesktopSave NotifyCode values. When you see one of those, you can save/load values from the file indicated by the FileName parameter using a class such as TIniFile.

## How can I add menu items to the code editor’s popup menu?

IOTAEditView.GetEditWindow.Form.FindComponent(‘EditorLocalMenu’) will return the editor’s TPopupMenu component that you can add to. Your added menu items will work best if you add them to the end of the popup menu and may not work at all if you associate an action with them. Note that you might want an IOTAEditorNotifier to determine when to add your new menu items to new editor windows.

## How does the native OTA deal with UNICODE strings in the editor?

Starting with Delphi 8, the OTA will usually return UNICODE editor content as UTF-8 encoded strings and expect UTF-8 strings when writing into the editor. This means that for many common low-ASCII characters (the most common in the Latin alphabet), the encoding will not differ form the ASCII encoding, but for some other characters, such a German umlaut, the UTF-8 encoding will result in 2-bytes in the string for this character. You can convert from UTF-8 returned strings to ANSI using Utf8ToAnsi and convert from ANSI strings to UTF-8 for insertion into the editor using AnsiToUtf8.

## How can I iterate over all units/forms in a project?

IOTAProject.ModuleCount can be used to iterate over all modules, and IOTAProject.GetModule returns a reference to IOTAModuleInfo which gives you the FileName, FormName, etc.

## How can I do custom painting or drawing (colors, lines, etc.) in the IDE code editor?

There isn’t any OTA support for custom drawing in the editor, beyond writing your own syntax highlighter (see IOTAHighlighter). All of the attempts to hack custom drawing into the code editor involve low level techniques such as windows hooks, runtime VMT patching, package export patching, etc. You have to manually calculate the position of characters onscreen, so you need to know a lot about how the editor draws characters, what portions of the code are folded, how the IDE painting changes with certain fonts and with italics involved, etc. All of these methods are complex, cause extra flickering in the editor, are difficult to debug, can cause IDE instability, and can also slow the editor down enough that it becomes less usable on slower machines.

## How can I publish a property of type T\[Custom\]Form?

It doesn’t work very well, but you can try to publish the property normally. The problem is that only currently created forms will be shown in the property editor, and storing an internal reference to one of those forms will often cause AVs when the target form is later closed. As a workaround, you can create a custom property editor that uses IOTAProject as above to get the class names of all forms in the project and insert them into the dropdown list for the property editor. Then store the form reference internally as a class name string, and use something like GetClass and RegisterClass to map a class name to a class type. With the class type, you can create the form at runtime. If you are sure your target form will always exist at runtime, another option to map from classes to instances is to search the Screen.Forms array.

## How can I create a form that docks into the IDE like the Object Inspector?

You need to descend from TDockableForm in the DesignIDE package’s DockForm unit and perform some magic to register your dockable form with the IDE. Here is a [docking form example](http://www.gexperts.org/examples/DockingForm.zip) should work in Delphi 7 – 2007 and shows how to declare a basic docking form. Compile the included package, install it into the IDE, and then look at the new menu item in the Help menu. Also, see [Allen Bauer’s article](http://edn.embarcadero.com/article/21114) on the CodeGear web site for an overview and a Delphi 5 example.

## How can I obtain the currently active form editor (IOTAFormEditor)?

<table><tbody><tr><td><p>1</p><p>2</p><p>3</p><p>4</p><p>5</p><p>6</p><p>7</p><p>8</p><p>9</p><p>10</p><p>11</p><p>12</p><p>13</p><p>14</p><p>15</p><p>16</p><p>17</p><p>18</p></td><td><div><p><code>function</code> <code>GetActiveFormEditor: IOTAFormEditor;</code></p><p><code>var</code></p><p><code>&nbsp;&nbsp;</code><code>Module: IOTAModule;</code></p><p><code>&nbsp;&nbsp;</code><code>Editor: IOTAEditor;</code></p><p><code>&nbsp;&nbsp;</code><code>i: </code><code>Integer</code><code>;</code></p><p><code>begin</code></p><p><code>&nbsp;&nbsp;</code><code>Result := </code><code>nil</code><code>;</code></p><p><code>&nbsp;&nbsp;</code><code>Module := (BorlandIDEServices </code><code>as</code> <code>IOTAModuleServices).CurrentModule;</code></p><p><code>&nbsp;&nbsp;</code><code>if</code> <code>Module&nbsp; </code><code>nil</code> <code>then</code></p><p><code>&nbsp;&nbsp;</code><code>begin</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>for</code> <code>i := </code><code>0</code> <code>to</code> <code>Module</code><code>.</code><code>GetModuleFileCount - </code><code>1</code> <code>do</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>begin</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</code><code>Editor := Module</code><code>.</code><code>GetModuleFileEditor(i);</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</code><code>if</code> <code>Supports(Editor, IOTAFormEditor, Result) </code><code>then</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</code><code>Break;</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>end</code><code>;</code></p><p><code>&nbsp;&nbsp;</code><code>end</code><code>;</code></p><p><code>end</code><code>;</code></p></div></td></tr></tbody></table>

## How can I obtain the current form designer interface (IFormDesigner)?

<table><tbody><tr><td><p>1</p><p>2</p><p>3</p><p>4</p><p>5</p><p>6</p><p>7</p><p>8</p><p>9</p></td><td><div><p><code>function</code> <code>GetActiveFormDesigner: IFormDesigner;</code></p><p><code>var</code></p><p><code>&nbsp;&nbsp;</code><code>FormEditor: IOTAFormEditor;</code></p><p><code>begin</code></p><p><code>&nbsp;&nbsp;</code><code>Result := </code><code>nil</code><code>;</code></p><p><code>&nbsp;&nbsp;</code><code>FormEditor := GetActiveFormEditor;</code></p><p><code>&nbsp;&nbsp;</code><code>if</code> <code>FormEditor&nbsp; </code><code>nil</code> <code>then</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>Result := (FormEditor </code><code>as</code> <code>INTAFormEditor).FormDesigner;</code></p><p><code>end</code><code>;</code></p></div></td></tr></tbody></table>

## How can I get a form editor from a module interface?

You should iterate through all of the ModuleFileEditors, to see which one implements IOTAFormEditor:

<table><tbody><tr><td><p>1</p><p>2</p><p>3</p><p>4</p><p>5</p><p>6</p><p>7</p><p>8</p><p>9</p><p>10</p><p>11</p><p>12</p><p>13</p><p>14</p><p>15</p></td><td><div><p><code>function</code> <code>GetFormEditorFromModule(Module: IOTAModule): IOTAFormEditor;</code></p><p><code>var</code></p><p><code>&nbsp;&nbsp;</code><code>i: </code><code>Integer</code><code>;</code></p><p><code>&nbsp;&nbsp;</code><code>Editor: IOTAEditor;</code></p><p><code>begin</code></p><p><code>&nbsp;&nbsp;</code><code>Result := </code><code>nil</code><code>;</code></p><p><code>&nbsp;&nbsp;</code><code>if</code> <code>Module = </code><code>nil</code> <code>then</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</code><code>Exit;</code></p><p><code>&nbsp;&nbsp;</code><code>for</code> <code>i := </code><code>0</code> <code>to</code> <code>Module</code><code>.</code><code>GetModuleFileCount - </code><code>1</code> <code>do</code></p><p><code>&nbsp;&nbsp;</code><code>begin</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>Editor := Module</code><code>.</code><code>GetModuleFileEditor(i);</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;</code><code>if</code> <code>Supports(Editor, IOTAFormEditor, Result) </code><code>then</code></p><p><code>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</code><code>Break;</code></p><p><code>&nbsp;&nbsp;</code><code>end</code><code>;</code></p><p><code>end</code><code>;</code></p></div></td></tr></tbody></table>

## Is there a way to determine if the user is editing a form or working in the code editor?

Starting with Delphi 6, there is IOTAModule.GetCurrentEditor for this purpose. If you find these methods don’t work for .h files in C++Builder try IOTAEditorServices.TopBuffer.FileName. You can’t do this using only the new Open Tools API in Delphi 5, but you can use the old API to get this information from ToolServices.GetCurrentFile.  
How can I tell when a module was removed from a project?

The old OTA had an fnRemovedFromProject notification flag, but this doesn’t exist in the new OTA. As a workaround, you can watch for changes to the project file using an IOTAEditorNotifier and the iterate over all modules to see which one might have been deleted, if any.

## How can I obtain the Name property of a form?

If the form is part of a loaded project, use IOTAModuleInfo.GetFormName. If the form is not part of a loaded project, you can try IOTAFormEditor.GetRootComponent.GetIComponent.Name, but it isn’t always reliable (it can cause AVs of the form is not visible). A more reliable method might be to force the form visible before calling GetRootComponent or you could manually scan the associated DFM stream for the form’s Name property.

## How can I create a method and then assign an event handler at design-time?

You need to use I\[Form\]Designer.CreateMethod from the DsgnIntf/DesignIntf unit and then SetMethodProp from the TypInfo unit. Here is a simple [Delphi 5/6 example](http://www.gexperts.org/examples/CreateMethod.pas) that uses both of these functions to create and assign an OnClick handler for the current form.

## How can I force the code editor to show a specific file tab?

You can either use IOTASourceEditor.Show or call IOTAActionServices.OpenFile and pass in the full path and filename of the file tab to activate.

## How can I determine the filename of the binary/exe/dll/bpl/ocx/etc. generated by a compile or build?

-   For Delphi 8 or greater, use IOTAProjectOptions.TargetName.
-   For earlier releases, the method is a lot more complex to implement because it involves potentially scanning for the $E directive that specifies the executable file extension for the project, and then looking for the binary file on the path specified by the “OptputDir” project option, or the project directory if that option is blank (among many other possibilities and complexities). The best way to implement such a tool might be to start with the sample code in CodeGear CodeCentral sample ID 19823.

## Known Open Tools API Bugs

## Known bugs in the Delphi 2007 Open Tools API (most also apply to earlier releases):

-   DLL experts can cause shutdown crashes under Vista and the Windows “This program has stopped working” dialog appears (QC 44578).
-   If you try to delete a component from a form using IOTAComponent.Delete, and that component is inherited from an ancestor form, the following incorrect error appears “Cannot rename component Button1, the component was introduced on ancestor form.” and then the IDE gives an infinite sequence of AVs when closing the module or trying to shut down the IDE (RAID 203770).
-   The indexes used for values returned by IOTAComponent.GetPropName(i) for VCL.NET do not match the indexes needed by by IOTAComponent.SetProp(i, Value), so the Index versions of GetPropValue and SetProp are unusable, since there is no way to know the right index to pass in (RAID 204184).
-   After changing the name of a created project using IOTAProject.FileName, the Project Manager does not properly update the full path/file name displayed for the project (RAID 205616).
-   The IOTAProjectMenuCreatorNotifier method does not fire for the project group node (RAID 213512).
-   IDesigner.GetProjectModules never fires the passed callback method (QC 20589).
-   You must implement IOTARepositoryWizard80 for all of the repository wizards (File|New dialog items) or they will not show up in the IDE (QC 20898).
-   SplashScreenServices.AddProductBitmap does nothing with only a single personality loaded (use SplashScreenServices.AddPluginBitmap instead) (QC 42320).

## Known bugs in the BDS 2006 Open Tools API (most also apply to earlier releases):

-   Calling IOTAActionServices.OpenProject on any .dpr file results in the error “Invalid at the top level of the document.”. You have to use IOTAActionServices.OpenFile, even though this is a project (RAID 203690).
-   IOTAProjectResource is no longer implemented by any of the project’s editors (QC 15657)
-   RemoveMenuCreatorNotifier does not actually remove the INTAProjectMenuCreatorNotifier from the project manager (QC 38098).
-   Adding a project to the existing project group fails unless the project is a package (QC 38281).

## Known bugs in the Delphi 2005 Open Tools API:

-   If you register a custom module using RegisterCustomModule, you will be unable to use the embedded designer with that form. The designer will always float, and you must use F12 to focus the form (fixed in BDS 2006).

## Known bugs in the Delphi 7 Open Tools API (most also apply to Delphi/BCB 6):

-   IOTAComponent.GetParent always returns nil.
-   Calling IOTAEditView.SetTempMsg makes the code editor’s Diagram tab disappear when clicking back in the source code editor.
-   Several of the IOTAProjectOptions do not work such as IncludeVersionInfo and ModuleAttribs. Also, some useful options are missing such as BreakOnException. Some options such as LibraryPath are not persisted across sessions.
-   The HowMany parameter of IOTAEditPosition.Delete is ignored. As a result, the method always deletes one character.
-   IOTASourceEditor.SetSyntaxHighlighter is deprecated and can no longer be used
-   Setting IOTAEditView.CursorPos doesn’t update the edit window’s cursor position in the status bar.
-   The IDE does not remove instances of IOTACustomMessage from the message view before unloading an expert. This can result in crashes as the IDE calls back into an unloaded library. The workaround is to call ClearToolMessages before your expert unloads, if it added custom messages.
-   IOTAToDoManager.ProjectChanged is never called.
-   You can’t add a keyboard binding for keys like Ctrl+/ and Ctrl+K.
-   IOTAResourceEntry.DataSize must be divisible by 4 (aligned to a 4-byte boundary), or you will get an RLINK32 error when compiling.

## Known bugs in the Delphi 6 Open Tools API (most also apply to Delphi/BCB 5):

-   TIModuleInterface.GetFormInterface is deprecated and always returns nil. You must use IOTAFormEditor instead.
-   The Open Tools keybinding interfaces sometimes raise AVs when using IOTAKeyBoardServices.AddKeyboardBinding.
-   IOTAEditView.PosToCharPos raises an AV in dfwedit.dll every time it is used.
-   IOTAEditorServices.TopView raises an AV in the coride package if called with no files open.

## Known bugs in the C++Builder 5.01 Open Tools API:

-   Given a regular unit without an associated form, calling IOTAModule.GetModuleFileCount returns 2 but IOTAModule.GetModuleFileEditor called with index 1 results in an AV and index 2 returns the .H file.
-   Setting the LibDir project option using IOTAProjectOptions.Values results in an AV.

## Known bugs in the Delphi 5.01 Open Tools API:

-   Calling IOTAModuleServices.OpenProject on a BPG file will crash the IDE. Instead, use IOTAModuleServices.OpenFile.
-   When querying IOTAProjectGroup.FileName, you won’t get a full pathname. Instead query the IOTAModule that implements IOTAProjectGroup for its FileName, and it will contain a full path.
-   The project options MajorVersion, MinorVersion, Release, and Build don’t update the project options dialog when set.
-   You can not use the keybinding interfaces to bind actions to keystrokes such as Ctrl+Enter, Shift+Enter, and non-shifted alpha-numeric characters.
-   When opening a BPG file, IOTAIDENotifier will send a blank filename parameter along with ofnFileOpened into the FileNotification method.
-   The IDE AVs or produces an I/O Error when specifying a file name without a complete path when implementing IOTAProjectCreator.GetFileName.
