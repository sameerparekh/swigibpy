/*
    SWIG interface file for Interactive Brokers API.
*/

%module(directors="1", docstring="Python wrapper for Interactive Brokers TWS C++ API") swigibpy

/* Turn on auto-generated docstrings */
%feature("autodoc", "1");

/* auto convert std::string and typedefs to Python strings */
%include "std_string.i"
typedef std::string IBString;

/* auto convert std::vector to Python lists */
%include "std_vector.i"

/* use boost template to generate shared pointer handling */
%include <boost_shared_ptr.i>

/* Inclusions for generated cpp file */
%{
#include "Shared/shared_ptr.h"

#include "Shared/IBString.h"
#include "Shared/EClient.h"
#include "Shared/EClientSocketBase.h"

#include "PosixSocketClient/EPosixClientSocket.h"
#include "Shared/EWrapper.h"

#include "Shared/CommissionReport.h"
#include "Shared/CommonDefs.h"
#include "Shared/Contract.h"
#include "Shared/Execution.h"
#include "Shared/Order.h"
#include "Shared/OrderState.h"
#include "Shared/ScannerSubscription.h"
#include "Shared/TagValue.h"
%}


/* Shared Pointers */
%shared_ptr(ComboLeg)
%shared_ptr(std::vector<boost::shared_ptr<ComboLeg> >)

%shared_ptr(OrderComboLeg)
%shared_ptr(std::vector<boost::shared_ptr<OrderComboLeg> >)

%shared_ptr(TagValue)
%shared_ptr(std::vector<boost::shared_ptr<TagValue> >)

/* Vector (list) containers */
%template(ComboLegList) std::vector<boost::shared_ptr<ComboLeg> >;
%template(OrderComboLegList) std::vector<boost::shared_ptr<OrderComboLeg> >;
%template(TagValueList) std::vector<boost::shared_ptr<TagValue> >;

/* 
   TWS use their own shared_ptr class, need to fool SWIG into thinking
   it's the standard boost::shared_ptr.
   This means the generated cpp file must be post-processed to remove
   references to boost (see setup.py).
*/
#define shared_ptr boost::shared_ptr

/*EWrapper will be subclassed in Python*/
%feature("director") EWrapper;
%feature("director:except") {
    if ($error != NULL) {
        throw Swig::DirectorMethodException();
    }
}

/* Exception handling */
%include exception.i
%exception {
    /*
        most errors should be propagated through to EWrapper->error,
        others should be added here as and when needed / encountered.
    */
    try {
        $action
    } catch(Swig::DirectorPureVirtualException &e) {
        /* Call to pure virtual method, raise not implemented error */
        PyErr_SetString(PyExc_NotImplementedError, "$decl not implemented");
        SWIG_fail;
    } catch(Swig::DirectorException &e) {
        /* Fail if there is a problem in the director proxy transport */
        SWIG_fail;
    } catch(std::exception& e) {
        /* Convert standard error to Exception */
        PyErr_SetString(PyExc_Exception, const_cast<char*>(e.what()));
        SWIG_fail;

    } catch(...) {
        /* Final catch all, results in runtime error */
        PyErr_SetString(PyExc_RuntimeError, "Unknown error caught in Interactive Brokers SWIG wrapper...");
        SWIG_fail;
    }
}

/* Grab the header files to be wrapped */
%include "Shared/CommissionReport.h"
%include "Shared/CommonDefs.h"
%include "Shared/Contract.h"
%include "Shared/EClient.h"
%include "Shared/EClientSocketBase.h"
%include "Shared/Execution.h"
%include "Shared/Order.h"
%include "Shared/OrderState.h"
%include "Shared/ScannerSubscription.h"
%include "Shared/TagValue.h"

/* Customise EPosixClientSocket so that TWS is automatically polled for messages when we are connected to it */
%pythoncode %{
import sys
import threading
from traceback import print_exc

class TWSPoller(threading.Thread):
    '''Continually polls TWS for any outstanding messages.
    
    Loops indefinitely until killed or a fatal error is encountered. Calls 
    TWS's `EClientSocketBase::checkMessages` function which blocks on socket 
    receive (synchronous I/O).
    '''

    def __init__(self, tws):
        super(TWSPoller, self).__init__()
        self.daemon = True
        self._tws = tws

    def run(self):
        '''Continually poll TWS'''
        ok = True
        while ok:
            ok = self._tws.checkMessages()

            if ok and (not self._tws or not self._tws.isConnected()):
                ok = False
%}
%pythonprepend EClientSocketBase::eConnect(const char *host, unsigned int port, int clientId=0) %{
    poll_auto = kwargs.pop('poll_auto', True)
%}
%pythonappend EClientSocketBase::eConnect(const char *host, unsigned int port, int clientId=0) %{
    if poll_auto and val:
        self.poller = TWSPoller(self)
        self.poller.start()
%}
%include "PosixSocketClient/EPosixClientSocket.h"

%feature("shadow") EWrapper::winError(const IBString &, int) %{
    def winError(self, str, lastError):
        '''Error in TWS API library'''
        sys.stderr.write("TWS Error - %s: %s\n" % (lastError, str))
%}
%feature("shadow") EWrapper::error(const int, const int, const IBString) %{
    def error(self, id, errorCode, errorString):
        '''Error during communication with TWS'''
        import sys
        if errorCode == 165: # Historical data sevice message
            sys.stderr.write("TWS Warning - %s: %s\n" % (errorCode, errorString))
        elif errorCode >= 501 and errorCode < 600: # Socket read failed
            sys.stderr.write("TWS Client Error - %s: %s\n" % (errorCode, errorString))
        elif errorCode >= 100 and errorCode < 1100:
            sys.stderr.write("TWS Error - %s: %s\n" % (errorCode, errorString))
        elif  errorCode >= 1100 and errorCode < 2100:
            sys.stderr.write("TWS System Error - %s: %s\n" % (errorCode, errorString))
        elif errorCode >= 2100 and errorCode <= 2110:
            sys.stderr.write("TWS Warning - %s: %s\n" % (errorCode, errorString))
        else:
            sys.stderr.write("TWS Error - %s: %s\n" % (errorCode, errorString))
%}
%include "Shared/EWrapper.h"
