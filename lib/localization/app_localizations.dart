import 'dart:async';

import 'package:flutter/widgets.dart';

class AppLocalizations {
  static final AppLocalizations _defaultInstance =
      AppLocalizations(const Locale('en'));
  static AppLocalizations? _lastLoadedInstance;

  final Locale locale;

  AppLocalizations(this.locale);

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('mr'),
    Locale('gu'),
  ];

  static AppLocalizations of(BuildContext context) {
    try {
      final instance =
          Localizations.of<AppLocalizations>(context, AppLocalizations);
      if (instance != null) {
        _lastLoadedInstance = instance;
        return instance;
      }
    } catch (_) {
      // Swallow FlutterError raised during early lifecycle access and fall back
    }
    return _lastLoadedInstance ?? _defaultInstance;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _keyedTranslations = {
    'notifications.status.enabled': {
      'en': 'notifications enabled',
      'hi': 'सूचनाएं सक्रिय कर दी गई हैं',
      'mr': 'सूचना सक्षम केली आहे',
      'gu': 'સૂચનાઓ સક્રિય થઈ ગઈ છે',
    },
    'notifications.status.disabled': {
      'en': 'notifications disabled',
      'hi': 'सूचनाएं निष्क्रिय कर दी गई हैं',
      'mr': 'सूचना निष्क्रिय केली आहे',
      'gu': 'સૂચનાઓ નિષ્ક્રિય કરી દેવામાં આવી છે',
    },
    'notifications.status.updateFailure': {
      'en': 'Failed to update notification setting.',
      'hi': 'सूचना सेटिंग अपडेट नहीं हो सकी।',
      'mr': 'सूचना सेटिंग अद्यतन करण्यात अयशस्वी.',
      'gu': 'સૂચના સેટિંગ અપડેટ થતું નથી.',
    },
    'settings.language.changed': {
      'en': 'Language switched to {language}',
      'hi': 'भाषा {language} में बदल दी गई है',
      'mr': 'भाषा {language} मध्ये बदलली आहे',
      'gu': 'ભાષા હવે {language} પર બદલી છે',
    },
    'settings.language.selectorTitle': {
      'en': 'App Language',
      'hi': 'ऐप भाषा',
      'mr': 'अॅपची भाषा',
      'gu': 'ઍપની ભાષા',
    },
    'settings.language.selectorSubtitle': {
      'en': 'Select the language for the entire application',
      'hi': 'पूरे ऐप के लिए भाषा चुनें',
      'mr': 'संपूर्ण अॅपसाठी भाषा निवडा',
      'gu': 'આખા એપ્લિકેશન માટે ભાષા પસંદ કરો',
    },
    'documentDetail.missingId': {
      'en': 'Document ID is missing',
      'hi': 'दस्तावेज़ ID उपलब्ध नहीं है',
      'mr': 'दस्तऐवज ID उपलब्ध नाही',
      'gu': 'દસ્તાવેજ ID ઉપલબ્ધ નથી',
    },
    'documentDetail.pdfPreviewTitle': {
      'en': 'PDF Preview',
      'hi': 'PDF पूर्वावलोकन',
      'mr': 'PDF पूर्वावलोकन',
      'gu': 'PDF પૂર્વદર્શન',
    },
    'documentDetail.imagePreviewTitle': {
      'en': 'Image Preview',
      'hi': 'छवि पूर्वावलोकन',
      'mr': 'प्रतिमा पूर्वदर्शन',
      'gu': 'છબી પૂર્વદર્શન',
    },
    'common.errorWithMessage': {
      'en': 'Error: {message}',
      'hi': 'त्रुटि: {message}',
      'mr': 'त्रुटी: {message}',
      'gu': 'ભૂલ: {message}',
    },
    'common.noToken': {
      'en': 'No authentication token available',
      'hi': 'प्रमाणीकरण टोकन उपलब्ध नहीं है',
      'mr': 'प्रमाणीकरण टोकन उपलब्ध नाही',
      'gu': 'પ્રમાણીકરણ ટોકન ઉપલબ્ધ નથી',
    },
    'documentDetail.previewUrlFailed': {
      'en': 'Failed to get preview URL: {message}',
      'hi': 'पूर्वावलोकन URL प्राप्त करने में विफल: {message}',
      'mr': 'पूर्वावलोकन URL मिळवण्यात अयशस्वी: {message}',
      'gu': 'પૂર્વદર્શન URL મેળવવામાં નિષ્ફળ: {message}',
    },
    'documentDetail.downloadSuccessPath': {
      'en': 'File downloaded: {path}',
      'hi': 'फ़ाइल डाउनलोड हुई: {path}',
      'mr': 'फाइल डाउनलोड झाली: {path}',
      'gu': 'ફાઇલ ડાઉનલોડ થઈ: {path}',
    },
    'common.downloadFailed': {
      'en': 'Download failed: {error}',
      'hi': 'डाउनलोड विफल: {error}',
      'mr': 'डाउनलोड अयशस्वी: {error}',
      'gu': 'ડાઉનલોડ નિષ્ફળ: {error}',
    },
    'common.invalidDocumentId': {
      'en': 'Invalid document ID',
      'hi': 'अमान्य दस्तावेज़ ID',
      'mr': 'अमान्य दस्तावेज ID',
      'gu': 'અમાન્ય દસ્તાવેજ ID',
    },
    'common.invalidDocument': {
      'en': 'Invalid document',
      'hi': 'अमान्य दस्तावेज़',
      'mr': 'अमान्य दस्तावेज',
      'gu': 'અમાન્ય દસ્તાવેજ',
    },
    'common.storagePermission': {
      'en': 'Storage permission required',
      'hi': 'स्टोरेज अनुमति आवश्यक है',
      'mr': 'संचयन परवानगी आवश्यक आहे',
      'gu': 'સંગ્રહની મંજૂરી જરૂરી છે',
    },
    'common.couldNotOpenFile': {
      'en': 'Could not open file: {error}',
      'hi': 'फ़ाइल नहीं खोल सके: {error}',
      'mr': 'फाइल उघडता आली नाही: {error}',
      'gu': 'ફાઇલ ખોલી શકાઈ નથી: {error}',
    },
    'common.deleteSuccess': {
      'en': 'File deleted',
      'hi': 'फ़ाइल हटाई गई',
      'mr': 'फाइल हटविली',
      'gu': 'ફાઇલ કાઢી નાખવામાં આવી',
    },
    'common.deleteFailed': {
      'en': 'Delete failed',
      'hi': 'हटाना विफल',
      'mr': 'हटवणे अयशस्वी',
      'gu': 'દૂર કરવામાં નિષ્ફળ',
    },
    'documentDetail.categoryLabel': {
      'en': 'Category:',
      'hi': 'श्रेणी:',
      'mr': 'वर्ग:',
      'gu': 'શ્રેણી:',
    },
    'documentDetail.uploadedOn': {
      'en': 'Uploaded on:',
      'hi': 'अपलोड दिनांक:',
      'mr': 'अपलोड दिनांक:',
      'gu': 'અપલોડ તારીખ:',
    },
    'documentDetail.untitled': {
      'en': 'Untitled',
      'hi': 'शीर्षक रहित',
      'mr': 'शीर्षकरहित',
      'gu': 'શીર્ષક વિના',
    },
    'common.unknown': {
      'en': 'Unknown',
      'hi': 'अज्ञात',
      'mr': 'अज्ञात',
      'gu': 'અજ્ઞાત',
    },
    'documents.uploadedOnShort': {
      'en': 'Uploaded:',
      'hi': 'अपलोड दिनांक:',
      'mr': 'अपलोड:',
      'gu': 'અપલોડ:',
    },
    'common.deleteFailedWithMessage': {
      'en': 'Failed to delete: {error}',
      'hi': 'हटाने में विफल: {error}',
      'mr': 'हटवण्यात अयशस्वी: {error}',
      'gu': 'દૂર કરવામાં નિષ્ફળ: {error}',
    },
    'common.notAvailable': {
      'en': 'N/A',
      'hi': 'उपलब्ध नहीं',
      'mr': 'उपलब्ध नाही',
      'gu': 'ઉપલબ્ધ નથી',
    },
    'common.clear': {
      'en': 'Clear',
      'hi': 'साफ़ करें',
      'mr': 'साफ करा',
      'gu': 'સાફ કરો',
    },
    'common.locationNotSet': {
      'en': 'Location not set',
      'hi': 'स्थान सेट नहीं है',
      'mr': 'स्थान सेट केलेले नाही',
      'gu': 'સ્થાન સેટ થયું નથી',
    },
    'categoryVault.searchHint': {
      'en': 'Search by name',
      'hi': 'नाम से खोजें',
      'mr': 'नावाने शोधा',
      'gu': 'નામથી શોધો',
    },
    'categoryVault.noDocsUploadedTitle': {
      'en': 'No documents uploaded yet',
      'hi': 'अभी तक कोई दस्तावेज़ अपलोड नहीं किया गया',
      'mr': 'अजून कोणतीही कागदपत्रे अपलोड केलेली नाहीत',
      'gu': 'હજી સુધી કોઈ દસ્તાવેજ અપલોડ કરાયેલ નથી',
    },
    'categoryVault.noDocsUploadedSubtitle': {
      'en': 'Upload documents to see them here',
      'hi': 'दस्तावेज़ यहां देखने के लिए अपलोड करें',
      'mr': 'कागदपत्रे येथे पाहण्यासाठी अपलोड करा',
      'gu': 'અહીં જોવા માટે દસ્તાવેજો અપલોડ કરો',
    },
    'categoryVault.noDocsFilteredTitle': {
      'en': 'No documents found for selected time period',
      'hi': 'चयनित समय अवधि के लिए कोई दस्तावेज़ नहीं मिला',
      'mr': 'निवडलेल्या कालावधीसाठी कोणतीही कागदपत्रे सापडली नाहीत',
      'gu': 'પસંદ કરાયેલ સમયગાળા માટે કોઈ દસ્તાવેજ મળ્યા નથી',
    },
    'categoryVault.noDocsFilteredSubtitle': {
      'en': 'Try selecting a different time filter',
      'hi': 'कृपया कोई अन्य समय फ़िल्टर चुनें',
      'mr': 'कृपया दुसरा वेळ फिल्टर निवडा',
      'gu': 'કૃપા કરીને અન્ય સમય ફિલ્ટર પસંદ કરો',
    },
    'requests.title': {
      'en': 'Doctor Requests',
      'hi': 'डॉक्टर अनुरोध',
      'mr': 'डॉक्टर विनंत्या',
      'gu': 'ડોક્ટર વિનંતીઓ',
    },
    'requests.errorTitle': {
      'en': 'Error loading requests',
      'hi': 'अनुरोध लोड करने में त्रुटि',
      'mr': 'विनंत्या लोड करण्यात त्रुटी',
      'gu': 'વિનંતીઓ લોડ કરવામાં ભૂલ',
    },
    'requests.noRequestsTitle': {
      'en': 'No pending requests',
      'hi': 'कोई लंबित अनुरोध नहीं',
      'mr': 'प्रलंबित विनंत्या नाहीत',
      'gu': 'કોઈ બાકી વિનંતીઓ નથી',
    },
    'requests.noRequestsSubtitle': {
      'en': 'You don\'t have any doctor access requests at the moment.',
      'hi': 'इस समय आपके पास कोई डॉक्टर एक्सेस अनुरोध नहीं है।',
      'mr': 'सध्या तुमच्याकडे डॉक्टर प्रवेश विनंत्या नाहीत.',
      'gu': 'હાલમાં તમારી પાસે કોઈ ડોક્ટર ઍક્સેસ વિનંતીઓ નથી.',
    },
    'requests.timeRemaining': {
      'en': '{time} left',
      'hi': '{time} शेष',
      'mr': '{time} बाकी',
      'gu': '{time} બાકી',
    },
    'requests.expired': {
      'en': 'Expired',
      'hi': 'समाप्त',
      'mr': 'कालबाह्य',
      'gu': 'સમાપ્ત',
    },
    'requests.doctorExperience': {
      'en': 'Experience: {experience}',
      'hi': 'अनुभव: {experience}',
      'mr': 'अनुभव: {experience}',
      'gu': 'અનુભવ: {experience}',
    },
    'requests.accept': {
      'en': 'Accept',
      'hi': 'स्वीकारें',
      'mr': 'स्वीकारा',
      'gu': 'સ્વીકારો',
    },
    'requests.decline': {
      'en': 'Decline',
      'hi': 'अस्वीकारें',
      'mr': 'नाकार',
      'gu': 'નકારો',
    },
    'requests.acceptedSuccess': {
      'en': 'Request accepted successfully',
      'hi': 'अनुरोध सफलतापूर्वक स्वीकार किया गया',
      'mr': 'विनंती यशस्वीपणे स्वीकारली',
      'gu': 'વિનંતી સફળતાપૂર્વક સ્વીકારવામાં આવી',
    },
    'requests.declinedSuccess': {
      'en': 'Request declined successfully',
      'hi': 'अनुरोध सफलतापूर्वक अस्वीकार किया गया',
      'mr': 'विनंती यशस्वीपणे नाकारली',
      'gu': 'વિનંતી સફળતાપૂર્વક નકારી દેવામાં આવી',
    },
    'requests.respondFailed': {
      'en': 'Failed to respond to request',
      'hi': 'अनुरोध का जवाब देने में विफल',
      'mr': 'विनंतीला प्रतिसाद देणे अयशस्वी',
      'gu': 'વિનંતીનો પ્રતિસાદ આપવામાં નિષ્ફળ',
    },
    'sos.title': {
      'en': 'Emergency SOS',
      'hi': 'आपातकालीन SOS',
      'mr': 'आपत्कालीन SOS',
      'gu': 'આપાતકાલીન SOS',
    },
    'sos.selectProfile': {
      'en': 'Select Profile',
      'hi': 'प्रोफ़ाइल चुनें',
      'mr': 'प्रोफाइल निवडा',
      'gu': 'પ્રોફાઇલ પસંદ કરો',
    },
    'sos.myProfile': {
      'en': 'My Profile',
      'hi': 'मेरा प्रोफ़ाइल',
      'mr': 'माझे प्रोफाइल',
      'gu': 'મારું પ્રોફાઇલ',
    },
    'sos.profileFallback': {
      'en': 'Profile',
      'hi': 'प्रोफ़ाइल',
      'mr': 'प्रोफाइल',
      'gu': 'પ્રોફાઇલ',
    },
    'sos.fullName': {
      'en': 'Full Name',
      'hi': 'पूरा नाम',
      'mr': 'पूर्ण नाव',
      'gu': 'પૂર્ણ નામ',
    },
    'sos.mobileNumber': {
      'en': 'Mobile Number',
      'hi': 'मोबाइल नंबर',
      'mr': 'मोबाइल क्रमांक',
      'gu': 'મોબાઇલ નંબર',
    },
    'sos.mobileHint': {
      'en': 'Mobile (auto-filled if available)',
      'hi': 'मोबाइल (यदि उपलब्ध है तो स्वतः भरें)',
      'mr': 'मोबाइल (उपलब्ध असल्यास स्वयंचलित भरा)',
      'gu': 'મોબાઇલ (ઉપલબ્ધ હોય તો આપમેળે ભરાશે)',
    },
    'sos.age': {
      'en': 'Age',
      'hi': 'आयु',
      'mr': 'वय',
      'gu': 'ઉમર',
    },
    'sos.currentLocation': {
      'en': 'Current Location',
      'hi': 'वर्तमान स्थान',
      'mr': 'सध्याचे स्थान',
      'gu': 'વર્તમાન સ્થાન',
    },
    'sos.locationHint': {
      'en': 'Location (empty)',
      'hi': 'स्थान (रिक्त)',
      'mr': 'स्थान (रिक्त)',
      'gu': 'સ્થાન (ખાલી)',
    },
    'sos.getLocation': {
      'en': 'Get location',
      'hi': 'स्थान प्राप्त करें',
      'mr': 'स्थान मिळवा',
      'gu': 'સ્થાન મેળવો',
    },
    'sos.accuracyLabel': {
      'en': 'Approx. accuracy ±{meters} m',
      'hi': 'अनुमानित सटीकता ±{meters} मी',
      'mr': 'अंदाजे अचूकता ±{meters} मी',
      'gu': 'અંદાજિત ચોકસાઈ ±{meters} મી',
    },
    'sos.allergiesTitle': {
      'en': 'Allergies (from profile)',
      'hi': 'एलर्जी (प्रोफ़ाइल से)',
      'mr': 'अॅलर्जी (प्रोफाइलमधून)',
      'gu': 'ઍલર્જી (પ્રોફાઇલમાંથી)',
    },
    'sos.allergiesNone': {
      'en': 'None reported',
      'hi': 'कोई रिपोर्ट नहीं',
      'mr': 'काहीही नोंदलेले नाही',
      'gu': 'કંઈ પણ નોંધાયું નથી',
    },
    'sos.currentTime': {
      'en': 'Current Time',
      'hi': 'वर्तमान समय',
      'mr': 'सध्याचा वेळ',
      'gu': 'વર્તમાન સમય',
    },
    'sos.notesTitle': {
      'en': 'Notes for responders',
      'hi': 'रिस्पॉन्डर्स के लिए नोट्स',
      'mr': 'प्रतिसादकर्त्यांसाठी टिपा',
      'gu': 'પ્રતિસાદ આપનારાઓ માટે નોંધો',
    },
    'sos.notesHint': {
      'en': 'Optional details (symptoms, hazards, nearby risks)',
      'hi': 'वैकल्पिक विवरण (लक्षण, खतरे, पास की जोखिम)',
      'mr': 'पर्यायी तपशील (लक्षणे, धोके, जवळचे जोखीम)',
      'gu': 'વૈકલ્પિક વિગતો (લક્ષણો, જોખમો, નજીકના જોખમ)',
    },
    'sos.sendButton': {
      'en': 'Send SOS',
      'hi': 'SOS भेजें',
      'mr': 'SOS पाठवा',
      'gu': 'SOS મોકલો',
    },
    'sos.sending': {
      'en': 'Sending...',
      'hi': 'भेजा जा रहा है...',
      'mr': 'पाठवित आहे...',
      'gu': 'મોકલાઈ રહ્યું છે...',
    },
    'sos.sendSuccess': {
      'en': 'SOS sent successfully.',
      'hi': 'SOS सफलतापूर्वक भेजा गया।',
      'mr': 'SOS यशस्वीपणे पाठवले.',
      'gu': 'SOS સફળતાપૂર્વક મોકલાયું.',
    },
    'sos.sendSuccessMass': {
      'en':
          'SOS sent. Multiple emergencies detected nearby. Please stay safe and follow official instructions.',
      'hi':
          'SOS भेजा गया। पास में कई आपात स्थितियाँ पाई गई हैं। कृपया सुरक्षित रहें और आधिकारिक निर्देशों का पालन करें।',
      'mr':
          'SOS पाठवले. जवळपास अनेक आपत्कालीन घटना आढळल्या. कृपया सुरक्षित रहा आणि अधिकृत सूचनांचे पालन करा.',
      'gu':
          'SOS મોકલાયું. નજીકમાં અનેક આપાતકાલીન ઘટનાઓ શોધાઈ. કૃપા કરીને સુરક્ષિત રહો અને સત્તાવાર સૂચનાઓનું પાલન કરો.',
    },
    'sos.sendFailed': {
      'en': 'Failed to send SOS',
      'hi': 'SOS भेजने में विफल',
      'mr': 'SOS पाठवण्यात अयशस्वी',
      'gu': 'SOS મોકલવામાં નિષ્ફળ',
    },
    'sos.locationMissing': {
      'en': 'Unable to detect your location. Please enable GPS and try again.',
      'hi':
          'आपका स्थान पता लगाने में असमर्थ। कृपया GPS सक्षम करें और पुनः प्रयास करें।',
      'mr':
          'आपले स्थान शोधता येत नाही. कृपया GPS सक्षम करा आणि पुन्हा प्रयत्न करा.',
      'gu':
          'તમારું સ્થાન શોધી શકાતું નથી. કૃપા કરીને GPS સક્રિય કરો અને ફરી પ્રયાસ કરો.',
    },
    'sos.locationServicesDisabled': {
      'en': 'Location services disabled. Please enable GPS on your device.',
      'hi': 'स्थान सेवाएँ अक्षम हैं। कृपया अपने डिवाइस पर GPS सक्षम करें।',
      'mr': 'स्थान सेवा अक्षम आहेत. कृपया आपल्या डिव्हाइसवर GPS सक्षम करा.',
      'gu': 'સ્થાન સેવાઓ નિષ્ક્રિય છે. કૃપા કરી તમારા ઉપકરણમાં GPS સક્રિય કરો.',
    },
    'sos.locationPermissionDenied': {
      'en': 'Location permission denied.',
      'hi': 'स्थान अनुमति अस्वीकृत।',
      'mr': 'स्थान परवानगी नाकारली.',
      'gu': 'સ્થાન પરવાનગી નકારી.',
    },
    'sos.locationPermissionForever': {
      'en':
          'Location permissions are permanently denied. Please enable them from settings.',
      'hi':
          'स्थान अनुमतियाँ स्थायी रूप से अस्वीकृत हैं। कृपया सेटिंग्स से सक्षम करें।',
      'mr':
          'स्थान परवानग्या कायमस्वरूपी नाकारल्या आहेत. कृपया सेटिंगमधून सक्षम करा.',
      'gu':
          'સ્થાન પરવાનગીઓ કાયમી રીતે નકારી દેવામાં આવી છે. કૃપા કરીને સેટિંગ્સમાંથી સક્રિય કરો.',
    },
    'sos.locationError': {
      'en': 'Failed to access location: {error}',
      'hi': 'स्थान तक पहुँचने में विफल: {error}',
      'mr': 'स्थानावर प्रवेश करण्यात अयशस्वी: {error}',
      'gu': 'સ્થાન પ્રાપ્ત કરવામાં નિષ્ફળ: {error}',
    },
    'sos.photoUploadFailed': {
      'en': 'Failed to upload photo. Please try again.',
      'hi': 'फ़ोटो अपलोड करने में विफल। कृपया पुनः प्रयास करें।',
      'mr': 'फोटो अपलोड करण्यात अयशस्वी. कृपया पुन्हा प्रयत्न करा.',
      'gu': 'ફોટો અપલોડ કરવામાં નિષ્ફળ. કૃપા કરીને ફરી પ્રયાસ કરો.',
    },
    'sos.photoSelectionFailed': {
      'en': 'Photo selection failed: {error}',
      'hi': 'फ़ोटो चयन विफल: {error}',
      'mr': 'फोटो निवड अयशस्वी: {error}',
      'gu': 'ફોટો પસંદગી નિષ્ફળ: {error}',
    },
    'sos.profileRequired': {
      'en': 'Select a MedicalVault profile to continue.',
      'hi': 'जारी रखने के लिए एक मेडिकलवॉल्ट प्रोफ़ाइल चुनें।',
      'mr': 'पुढे जाण्यासाठी मेडिकलव्हॉल्ट प्रोफाइल निवडा.',
      'gu': 'આગળ વધવા માટે એક MedicalVault પ્રોફાઇલ પસંદ કરો.',
    },
    'sos.profileNeedsPhoto': {
      'en': 'Selected profile has no photo. Please upload a photo instead.',
      'hi': 'चयनित प्रोफ़ाइल में फोटो नहीं है। कृपया फोटो अपलोड करें।',
      'mr': 'निवडलेल्या प्रोफाइलमध्ये फोटो नाही. कृपया फोटो अपलोड करा.',
      'gu': 'પસંદ કરેલ પ્રોફાઇલમાં ફોટો નથી. કૃપા કરીને ફોટો અપલોડ કરો.',
    },
    'lostReport.photoRequired': {
      'en': 'Please upload a recent photo of the lost person.',
      'hi': 'कृपया लापता व्यक्ति का हालिया फोटो अपलोड करें।',
      'mr': 'कृपया हरवलेल्या व्यक्तीचा अलीकडचा फोटो अपलोड करा.',
      'gu': 'કૃપા કરીને ગુમ થયેલ વ્યક્તિનો તાજો ફોટો અપલોડ કરો.',
    },
    'lostReport.title': {
      'en': 'Report Lost Person',
      'hi': 'लापता व्यक्ति की रिपोर्ट करें',
      'mr': 'हरवलेल्या व्यक्तीची नोंद करा',
      'gu': 'ગુમ થયેલ વ્યક્તિની જાણ કરો',
    },
    'lostReport.who': {
      'en': 'Who are you reporting for?',
      'hi': 'आप किसके लिए रिपोर्ट कर रहे हैं?',
      'mr': 'तुम्ही कोणासाठी अहवाल देत आहात?',
      'gu': 'તમે કોના માટે રિપોર્ટ કરી રહ્યા છો?',
    },
    'lostReport.optionProfile': {
      'en': 'This MedicalVault profile',
      'hi': 'यह मेडिकलवॉल्ट प्रोफ़ाइल',
      'mr': 'ही मेडिकलव्हॉल्ट प्रोफाइल',
      'gu': 'આ MedicalVault પ્રોફાઇલ',
    },
    'lostReport.optionOther': {
      'en': 'Someone else (family / friend)',
      'hi': 'कोई और (परिवार / मित्र)',
      'mr': 'इतर कोणी (कुटुंब / मित्र)',
      'gu': 'બીજો કોઈ (કુટુંબ / મિત્ર)',
    },
    'lostReport.noProfiles': {
      'en': 'No linked profiles found. Switch to "Someone else" to continue.',
      'hi': 'कोई लिंक्ड प्रोफ़ाइल नहीं मिली। जारी रखने के लिए "कोई और" चुनें।',
      'mr':
          'कोणतीही लिंक केलेली प्रोफाइल सापडली नाहीत. पुढे जाण्यासाठी "इतर कोणी" निवडा.',
      'gu': 'કોઈ જોડાયેલ પ્રોફાઇલ મળી નથી. આગળ વધવા માટે "બીજો કોઈ" પસંદ કરો.',
    },
    'lostReport.selectProfileLabel': {
      'en': 'Select MedicalVault profile',
      'hi': 'मेडिकलवॉल्ट प्रोफ़ाइल चुनें',
      'mr': 'मेडिकलव्हॉल्ट प्रोफाइल निवडा',
      'gu': 'MedicalVault પ્રોફાઇલ પસંદ કરો',
    },
    'lostReport.nameLabel': {
      'en': 'Name (optional)',
      'hi': 'नाम (वैकल्पिक)',
      'mr': 'नाव (पर्यायी)',
      'gu': 'નામ (વૈકલ્પિક)',
    },
    'lostReport.ageLabel': {
      'en': 'Approximate Age',
      'hi': 'लगभग आयु',
      'mr': 'अंदाजे वय',
      'gu': 'અંદાજિત ઉમર',
    },
    'lostReport.ageValidation': {
      'en': 'Enter a valid age',
      'hi': 'मान्य आयु दर्ज करें',
      'mr': 'वैध वय प्रविष्ट करा',
      'gu': 'માન્ય ઉમર દાખલ કરો',
    },
    'lostReport.genderLabel': {
      'en': 'Gender',
      'hi': 'लिंग',
      'mr': 'लिंग',
      'gu': 'લિંગ',
    },
    'lostReport.genderMale': {
      'en': 'Male',
      'hi': 'पुरुष',
      'mr': 'पुरुष',
      'gu': 'પુરુષ',
    },
    'lostReport.genderFemale': {
      'en': 'Female',
      'hi': 'महिला',
      'mr': 'महिला',
      'gu': 'સ્ત્રી',
    },
    'lostReport.genderOther': {
      'en': 'Other',
      'hi': 'अन्य',
      'mr': 'इतर',
      'gu': 'અન્ય',
    },
    'lostReport.genderUnknown': {
      'en': 'Unknown',
      'hi': 'अज्ञात',
      'mr': 'अज्ञात',
      'gu': 'અજ્ઞાત',
    },
    'lostReport.descriptionLabel': {
      'en': 'Description (clothing, marks, identification details)',
      'hi': 'विवरण (कपड़े, निशान, पहचान संबंधी विवरण)',
      'mr': 'वर्णन (कपडे, खुणा, ओळख तपशील)',
      'gu': 'વર્ણન (કપડાં, નિશાન, ઓળખ વિગતો)',
    },
    'lostReport.descriptionValidation': {
      'en': 'Please describe the person and last seen details.',
      'hi': 'कृपया व्यक्ति और अंतिम बार देखी गई जानकारी का वर्णन करें।',
      'mr': 'कृपया व्यक्तीचे आणि शेवटचे पाहिलेले तपशील वर्णन करा.',
      'gu': 'કૃપા કરીને વ્યક્તિ અને છેલ્લે જોવામાં આવેલ વિગતો વર્ણવો.',
    },
    'lostReport.medicalNotesLabel': {
      'en': 'Medical notes (optional)',
      'hi': 'चिकित्सा नोट्स (वैकल्पिक)',
      'mr': 'वैद्यकीय नोंदी (पर्यायी)',
      'gu': 'તબીબી નોંધો (વૈકલ્પિક)',
    },
    'lostReport.medicalNotesHint': {
      'en': 'E.g. Diabetic, BP patient, needs medication, etc.',
      'hi': 'उदा. मधुमेह, बीपी रोगी, दवा की आवश्यकता, आदि',
      'mr': 'उदा. मधुमेह, बीपी रुग्ण, औषधांची गरज इ.',
      'gu': 'દા.ત. ડાયાબિટીસ, બીપી દર્દી, દવા જરૂરી, વગેરે',
    },
    'lostReport.photoSectionTitle': {
      'en': 'Photo',
      'hi': 'फोटो',
      'mr': 'फोटो',
      'gu': 'ફોટો',
    },
    'lostReport.photoUseProfile': {
      'en': 'Use MedicalVault profile photo',
      'hi': 'मेडिकलवॉल्ट प्रोफ़ाइल फोटो का उपयोग करें',
      'mr': 'मेडिकलव्हॉल्ट प्रोफाइल फोटो वापरा',
      'gu': 'MedicalVault પ્રોફાઇલ ફોટો વાપરો',
    },
    'lostReport.photoUploadOption': {
      'en': 'Upload a recent photo',
      'hi': 'हालिया फोटो अपलोड करें',
      'mr': 'अलीकडचा फोटो अपलोड करा',
      'gu': 'તાજો ફોટો અપલોડ કરો',
    },
    'lostReport.photoCamera': {
      'en': 'Camera',
      'hi': 'कैमरा',
      'mr': 'कॅमेरा',
      'gu': 'કૅમેરા',
    },
    'lostReport.photoGallery': {
      'en': 'Gallery',
      'hi': 'गैलरी',
      'mr': 'गॅलरी',
      'gu': 'ગૅલેરી',
    },
    'lostReport.noPhoto': {
      'en': 'No photo uploaded yet.',
      'hi': 'अभी तक कोई फोटो अपलोड नहीं किया गया है।',
      'mr': 'अजून कोणताही फोटो अपलोड केलेला नाही.',
      'gu': 'હજી સુધી કોઈ ફોટો અપલોડ કરવામાં આવ્યો નથી.',
    },
    'lostReport.lastSeenTime': {
      'en': 'Last seen time',
      'hi': 'अंतिम बार देखा गया समय',
      'mr': 'शेवटचे पाहण्याचा वेळ',
      'gu': 'છેલ્લે જોવા મળેલો સમય',
    },
    'lostReport.edit': {
      'en': 'Edit',
      'hi': 'संपादित करें',
      'mr': 'संपादित करा',
      'gu': 'સંપાદિત કરો',
    },
    'lostReport.lastSeenLocation': {
      'en': 'Last seen location',
      'hi': 'अंतिम बार देखा गया स्थान',
      'mr': 'शेवटचे पाहिलेले स्थान',
      'gu': 'છેલ્લે જોવા મળેલું સ્થળ',
    },
    'lostReport.useCurrent': {
      'en': 'Use current',
      'hi': 'वर्तमान का उपयोग करें',
      'mr': 'सध्याचे वापरा',
      'gu': 'વર્તમાન વાપરો',
    },
    'lostReport.useCurrentLocation': {
      'en': 'Use Current Location',
      'hi': 'वर्तमान स्थान उपयोग करें',
      'mr': 'सध्याचे स्थान वापरा',
      'gu': 'વર્તમાન સ્થાન વાપરો',
    },
    'lostReport.pickOnMap': {
      'en': 'Pick on Map',
      'hi': 'मानचित्र पर चुनें',
      'mr': 'नकाशावर निवडा',
      'gu': 'નકશા પર પસંદ કરો',
    },
    'lostReport.searchInMaps': {
      'en': 'Search in Maps',
      'hi': 'मानचित्र में खोजें',
      'mr': 'नकाशामध्ये शोधा',
      'gu': 'નકશામાં શોધો',
    },
    'lostReport.tapToSelect': {
      'en': 'Tap on the map to select location',
      'hi': 'स्थान चुनने के लिए मानचित्र पर टैप करें',
      'mr': 'स्थान निवडण्यासाठी नकाशावर टॅप करा',
      'gu': 'સ્થાન પસંદ કરવા માટે નકશા પર ટેપ કરો',
    },
    'lostReport.mapError': {
      'en': 'Map error: {error}',
      'hi': 'मानचित्र त्रुटि: {error}',
      'mr': 'नकाशा त्रुटी: {error}',
      'gu': 'નકશા ભૂલ: {error}',
    },
    'lostReport.loadingMap': {
      'en': 'Loading map...',
      'hi': 'मानचित्र लोड हो रहा है...',
      'mr': 'नकाशा लोड होत आहे...',
      'gu': 'નકશો લોડ થઈ રહ્યો છે...',
    },
    'lostReport.openInMaps': {
      'en': 'Open in Maps',
      'hi': 'मानचित्र में खोलें',
      'mr': 'नकाशामध्ये उघडा',
      'gu': 'નકશામાં ખોલો',
    },
    'common.cancel': {
      'en': 'Cancel',
      'hi': 'रद्द करें',
      'mr': 'रद्द करा',
      'gu': 'રદ કરો',
    },
    'lostReport.submit': {
      'en': 'Submit Lost Report',
      'hi': 'लापता रिपोर्ट जमा करें',
      'mr': 'हरवलेल्याची नोंद सादर करा',
      'gu': 'ગુમ થયેલની જાણ કરો',
    },
    'lostReport.submitSuccess': {
      'en': 'Lost person report submitted.',
      'hi': 'लापता व्यक्ति की रिपोर्ट जमा की गई।',
      'mr': 'हरवलेल्या व्यक्तीचा अहवाल सादर झाला.',
      'gu': 'ગુમ થયેલ વ્યક્તિનો રિપોર્ટ સબમિટ થયો.',
    },
    'lostReport.submitFailure': {
      'en': 'Failed to submit lost person report.',
      'hi': 'लापता व्यक्ति की रिपोर्ट जमा करने में विफल।',
      'mr': 'हरवलेल्या व्यक्तीचा अहवाल सादर करण्यात अयशस्वी.',
      'gu': 'ગુમ થયેલ વ્યક્તિનો રિપોર્ટ સબમિટ કરવામાં નિષ્ફળ.',
    },
    'lostReport.submitError': {
      'en': 'Unexpected error: {error}',
      'hi': 'अप्रत्याशित त्रुटि: {error}',
      'mr': 'अनपेक्षित त्रुटी: {error}',
      'gu': 'અપેક્ષિતથી ભિન્ન ભૂલ: {error}',
    },
    'lostReport.info': {
      'en':
          'An admin will review the report and share updates on suggested matches.',
      'hi':
          'एक प्रशासक रिपोर्ट की समीक्षा करेगा और सुझाए गए मैचों पर अपडेट साझा करेगा।',
      'mr':
          'प्रशासक अहवालाचे पुनरावलोकन करेल आणि सुचवलेल्या जुळणींच्या अद्ययावत माहिती शेअर करेल.',
      'gu':
          'એડમિન રિપોર્ટની સમીક્ષા કરશે અને સૂચિત મેળાવો અંગે અપડેટ શેર કરશે.',
    },
    'lostReport.profileRequired': {
      'en': 'Select a MedicalVault profile to continue.',
      'hi': 'जारी रखने के लिए एक मेडिकलवॉल्ट प्रोफ़ाइल चुनें।',
      'mr': 'पुढे जाण्यासाठी मेडिकलव्हॉल्ट प्रोफाइल निवडा.',
      'gu': 'આગળ વધવા માટે MedicalVault પ્રોફાઇલ પસંદ કરો.',
    },
    'lostReport.profileNeedsPhoto': {
      'en': 'Selected profile has no photo. Please upload a photo instead.',
      'hi': 'चयनित प्रोफ़ाइल में फोटो नहीं है। कृपया फोटो अपलोड करें।',
      'mr': 'निवडलेल्या प्रोफाइलमध्ये फोटो नाही. कृपया फोटो अपलोड करा.',
      'gu': 'પસંદ કરેલ પ્રોફાઇલમાં ફોટો નથી. કૃપા કરીને ફોટો અપલોડ કરો.',
    },
    'lostReport.uploadedPhotoName': {
      'en': 'Uploaded photo',
      'hi': 'अपलोड की गई फोटो',
      'mr': 'अपलोड केलेला फोटो',
      'gu': 'અપલોડ કરેલો ફોટો',
    },
    'lostReport.selectOnMap': {
      'en': 'Select on Map',
      'hi': 'मानचित्र पर चुनें',
      'mr': 'नकाशावर निवडा',
      'gu': 'નકશા પર પસંદ કરો',
    },
    'lostReport.openMaps': {
      'en': 'Open Maps',
      'hi': 'मानचित्र खोलें',
      'mr': 'नकाशा उघडा',
      'gu': 'નકશા ખોલો',
    },
    'lostReport.enterCoordinates': {
      'en': 'Enter Coordinates',
      'hi': 'निर्देशांक दर्ज करें',
      'mr': 'निर्देशांक प्रविष्ट करा',
      'gu': 'કોઓર્ડિનેટ્સ દાખલ કરો',
    },
    'lostReport.latitude': {
      'en': 'Latitude',
      'hi': 'अक्षांश',
      'mr': 'अक्षांश',
      'gu': 'અક્ષાંશ',
    },
    'lostReport.longitude': {
      'en': 'Longitude',
      'hi': 'देशांतर',
      'mr': 'रेखांश',
      'gu': 'રેખાંશ',
    },
    'lostReport.selected': {
      'en': 'Selected',
      'hi': 'चयनित',
      'mr': 'निवडलेले',
      'gu': 'પસંદ કરેલ',
    },
    'lostReport.invalidCoordinates': {
      'en':
          'Invalid coordinates. Please enter valid latitude (-90 to 90) and longitude (-180 to 180).',
      'hi':
          'अमान्य निर्देशांक। कृपया वैध अक्षांश (-90 से 90) और देशांतर (-180 से 180) दर्ज करें।',
      'mr':
          'अवैध निर्देशांक. कृपया वैध अक्षांश (-90 ते 90) आणि रेखांश (-180 ते 180) प्रविष्ट करा.',
      'gu':
          'અમાન્ય કોઓર્ડિનેટ્સ. કૃપા કરીને માન્ય અક્ષાંશ (-90 થી 90) અને રેખાંશ (-180 થી 180) દાખલ કરો.',
    },
    'lostReport.selectLocation': {
      'en': 'Select Location',
      'hi': 'स्थान चुनें',
      'mr': 'स्थान निवडा',
      'gu': 'સ્થાન પસંદ કરો',
    },
    'lostReport.mapsNotAvailable': {
      'en': 'Google Maps is not available on this device.',
      'hi': 'इस डिवाइस पर Google Maps उपलब्ध नहीं है।',
      'mr': 'या डिव्हाइसवर Google Maps उपलब्ध नाही.',
      'gu': 'આ ઉપકરણ પર Google Maps ઉપલબ્ધ નથી.',
    },
    'myVault.searchHint': {
      'en': 'Search',
      'hi': 'खोजें',
      'mr': 'शोधा',
      'gu': 'શોધો',
    },
    'myVault.category.all': {
      'en': 'All',
      'hi': 'सभी',
      'mr': 'सर्व',
      'gu': 'બધા',
    },
    'myVault.timeFilterTitle': {
      'en': 'Time Filter',
      'hi': 'समय फ़िल्टर',
      'mr': 'वेळ फिल्टर',
      'gu': 'સમય ફિલ્ટર',
    },
    'myVault.timeFilter.all': {
      'en': 'All',
      'hi': 'सभी',
      'mr': 'सर्व',
      'gu': 'બધા',
    },
    'myVault.timeFilter.1month': {
      'en': '1 Month',
      'hi': '1 महीना',
      'mr': '1 महिना',
      'gu': '1 મહિનો',
    },
    'myVault.timeFilter.3months': {
      'en': '3 Months',
      'hi': '3 महीने',
      'mr': '3 महिने',
      'gu': '3 મહિના',
    },
    'myVault.timeFilter.6months': {
      'en': '6 Months',
      'hi': '6 महीने',
      'mr': '6 महिने',
      'gu': '6 મહિના',
    },
    'myVault.timeFilter.12months': {
      'en': '12 Months',
      'hi': '12 महीने',
      'mr': '12 महिने',
      'gu': '12 મહિના',
    },
    'myVault.sortTitle': {
      'en': 'Sort By',
      'hi': 'क्रमबद्ध करें',
      'mr': 'क्रमबद्ध करा',
      'gu': 'ક્રમબદ્ધ કરો',
    },
    'myVault.sort.newestFirst': {
      'en': 'Newest First',
      'hi': 'नवीनतम पहले',
      'mr': 'नवीन प्रथम',
      'gu': 'સર્વપ્રથમ નવા',
    },
    'myVault.sort.oldestFirst': {
      'en': 'Oldest First',
      'hi': 'सबसे पुराने पहले',
      'mr': 'जुन्या प्रथम',
      'gu': 'સૌથી જુના પહેલા',
    },
    'myVault.sort.nameAZ': {
      'en': 'Name A-Z',
      'hi': 'नाम A-Z',
      'mr': 'नाव A-Z',
      'gu': 'નામ A-Z',
    },
    'myVault.sort.nameZA': {
      'en': 'Name Z-A',
      'hi': 'नाम Z-A',
      'mr': 'नाव Z-A',
      'gu': 'નામ Z-A',
    },
    'myVault.noDocuments': {
      'en': 'No documents found',
      'hi': 'कोई दस्तावेज़ नहीं मिला',
      'mr': 'कोणतीही कागदपत्रे सापडली नाहीत',
      'gu': 'કોઈ દસ્તાવેજ મળ્યા નથી',
    },
    'myVault.documentsCount': {
      'en': 'files',
      'hi': 'फाइलें',
      'mr': 'फाइल्स',
      'gu': 'ફાઈલો',
    },
    'myVault.uploadDocument': {
      'en': 'Upload Document',
      'hi': 'दस्तावेज़ अपलोड करें',
      'mr': 'दस्तावेज अपलोड करा',
      'gu': 'દસ્તાવેજ અપલોડ કરો',
    },
    'myVault.downloadedToDownloads': {
      'en': 'File downloaded to Downloads folder',
      'hi': 'फ़ाइल डाउनलोड फ़ोल्डर में डाउनलोड हुई',
      'mr': 'फाइल डाउनलोड्स फोल्डरमध्ये डाउनलोड झाली',
      'gu': 'ફાઇલ ડાઉનલોડ્સ ફોલ્ડરમાં સેવ થઈ',
    },
    'myVault.deleteDocument.title': {
      'en': 'Delete Document',
      'hi': 'दस्तावेज़ हटाएं',
      'mr': 'दस्तावेज हटवा',
      'gu': 'દસ્તાવેજ કાઢી નાખો',
    },
    'myVault.deleteDocument.message': {
      'en':
          'Are you sure you want to delete "{fileName}"? This action cannot be undone.',
      'hi':
          'क्या आप वाकई "{fileName}" को हटाना चाहते हैं? यह कार्रवाई पूर्ववत नहीं की जा सकती।',
      'mr':
          'तुम्हाला खरोखर "{fileName}" हटवायची आहे का? ही क्रिया पૂर्ववत करता येत नाही.',
      'gu':
          'શું તમે ખરેખર "{fileName}" કાઢી નાખવા માંગો છો? આ ક્રિયા પૂર્વવત્ કરી શકાતી નથી.',
    },
    'myVault.editDocument.title': {
      'en': 'Edit Document',
      'hi': 'दस्तावेज़ संपादित करें',
      'mr': 'दस्तावेज़ संपादित करा',
      'gu': 'દસ્તાવેજ સંપાદિત કરો',
    },
    'myVault.editDocument.titleLabel': {
      'en': 'Title',
      'hi': 'शीर्षक',
      'mr': 'शीर्षक',
      'gu': 'શીર્ષક',
    },
    'myVault.editDocument.titleHint': {
      'en': 'Enter document title',
      'hi': 'दस्तावेज़ शीर्षक दर्ज करें',
      'mr': 'दस्तावेज़ शीर्षक प्रविष्ट करा',
      'gu': 'દસ્તાવેજ શીર્ષક દાખલ કરો',
    },
    'myVault.editDocument.categoryLabel': {
      'en': 'Category',
      'hi': 'श्रेणी',
      'mr': 'श्रेणी',
      'gu': 'શ્રેણી',
    },
    'myVault.editDocument.dateLabel': {
      'en': 'Date',
      'hi': 'तारीख',
      'mr': 'तारीख',
      'gu': 'તારીખ',
    },
    'myVault.editDocument.descriptionLabel': {
      'en': 'Description',
      'hi': 'विवरण',
      'mr': 'विवरण',
      'gu': 'વર્ણન',
    },
    'myVault.editDocument.descriptionHint': {
      'en': 'Enter document description',
      'hi': 'दस्तावेज़ विवरण दर्ज करें',
      'mr': 'दस्तावेज़ विवरण प्रविष्ट करा',
      'gu': 'દસ્તાવેજ વર્ણન દાખલ કરો',
    },
    'myVault.editDocument.notesLabel': {
      'en': 'Notes',
      'hi': 'नोट्स',
      'mr': 'नोट्स',
      'gu': 'નોંધો',
    },
    'myVault.editDocument.notesHint': {
      'en': 'Enter additional notes',
      'hi': 'अतिरिक्त नोट्स दर्ज करें',
      'mr': 'अतिरिक्त नोट्स प्रविष्ट करा',
      'gu': 'અતિરિક્ત નોંધો દાખલ કરો',
    },
    'myVault.editDocument.success': {
      'en': 'Document updated successfully',
      'hi': 'दस्तावेज़ सफलतापूर्वक अपडेट किया गया',
      'mr': 'दस्तावेज़ यशस्वीरित्या अद्यतन झाले',
      'gu': 'દસ્તાવેજ સફળતાપૂર્વક અપડેટ થયું',
    },
    'myVault.editDocument.failed': {
      'en': 'Failed to update document',
      'hi': 'दस्तावेज़ अपडेट करने में विफल',
      'mr': 'दस्तावेज़ अद्यतन करण्यात अयशस्वी',
      'gu': 'દસ્તાવેજ અપડેટ કરવામાં નિષ્ફળ',
    },
    'common.preview': {
      'en': 'Preview',
      'hi': 'पूर्वावलोकन',
      'mr': 'पूर्वदर्शन',
      'gu': 'પૂર્વદર્શન',
    },
    'common.download': {
      'en': 'Download',
      'hi': 'डाउनलोड',
      'mr': 'डाउनलोड',
      'gu': 'ડાઉનલોદ',
    },
    'common.delete': {
      'en': 'Delete',
      'hi': 'हटाएँ',
      'mr': 'काढा',
      'gu': 'દૂર કરો',
    },
    'common.retry': {
      'en': 'Retry',
      'hi': 'पुनः प्रयास करें',
      'mr': 'पुन्हा प्रयत्न करा',
      'gu': 'ફરી પ્રયાસ કરો',
    },
    'pdf.loading': {
      'en': 'Loading PDF...',
      'hi': 'PDF लोड हो रहा है...',
      'mr': 'PDF लोड होत आहे...',
      'gu': 'PDF લોડ થઈ રહ્યું છે...',
    },
    'pdf.failedTitle': {
      'en': 'Failed to load PDF',
      'hi': 'PDF लोड करने में विफल',
      'mr': 'PDF लोड करण्यात अयशस्वी',
      'gu': 'PDF લોડ કરવામાં નિષ્ફળ',
    },
    'pdf.retryWithCount': {
      'en': 'Retry ({current}/{total})',
      'hi': 'पुनः प्रयास ({current}/{total})',
      'mr': 'पुन्हा प्रयत्न ({current}/{total})',
      'gu': 'ફરી પ્રયાસ ({current}/{total})',
    },
    'pdf.failAfterAttempts': {
      'en':
          'Failed to load PDF after {max} attempts. Please check your internet connection and try again.',
      'hi':
          '{max} प्रयासों के बाद PDF लोड नहीं हो पाया। कृपया अपना इंटरनेट कनेक्शन जांचें और पुनः प्रयास करें।',
      'mr':
          '{max} प्रयत्नांनंतर PDF लोड झाले नाही. कृपया आपले इंटरनेट कनेक्शन तपासा आणि पुन्हा प्रयत्न करा.',
      'gu':
          '{max} પ્રયત્નો પછી PDF લોડ કરી શકાયું નથી. કૃપા કરીને તમારું ઇન્ટરનેટ કનેક્શન તપાસો અને ફરી પ્રયાસ કરો.',
    },
    'image.failedTitle': {
      'en': 'Failed to load image',
      'hi': 'छवि लोड करने में विफल',
      'mr': 'प्रतिमा लोड करण्यात अयशस्वी',
      'gu': 'છબી લોડ કરવામાં નિષ્ફળ',
    },
    'image.errorLoading': {
      'en': 'Error loading image: {error}',
      'hi': 'छवि लोड करने में त्रुटि: {error}',
      'mr': 'प्रतिमा लोड करताना त्रुटी: {error}',
      'gu': 'છબી લોડ કરતી વખતે ભૂલ: {error}',
    },
    'image.noData': {
      'en': 'No image data available',
      'hi': 'कोई छवि डेटा उपलब्ध नहीं है',
      'mr': 'प्रतिमा डेटा उपलब्ध नाही',
      'gu': 'કોઈ છબી માહિતી ઉપલબ્ધ નથી',
    },
    'qr.title': {
      'en': 'QR Code',
      'hi': 'QR कोड',
      'mr': 'QR कोड',
      'gu': 'QR કોડ',
    },
    'qr.instructions': {
      'en': 'Doctor will scan this QR to request access',
      'hi': 'डॉक्टर एक्सेस का अनुरोध करने के लिए इस QR को स्कैन करेंगे',
      'mr': 'डॉक्टर प्रवेशाची विनंती करण्यासाठी हा QR स्कॅन करतील',
      'gu': 'ડોક્ટર ઍક્સેસ વિનંતી માટે આ QR સ્કેન કરશે',
    },
    'qr.share': {
      'en': 'Share QR',
      'hi': 'QR साझा करें',
      'mr': 'QR शेअर करा',
      'gu': 'QR શેર કરો',
    },
    'qr.regenerate': {
      'en': 'Regenerate QR',
      'hi': 'QR पुनः उत्पन्न करें',
      'mr': 'QR पुन्हा तयार करा',
      'gu': 'QR ફરીથી બનાવો',
    },
    'qr.accessHelp': {
      'en': 'How QR access works?',
      'hi': 'QR एक्सेस कैसे काम करता है?',
      'mr': 'QR प्रवेश कसा कार्य करतो?',
      'gu': 'QR ઍક્સેસ કેવી રીતે કાર્ય કરે છે?',
    },
    'qr.shareText': {
      'en': 'Share this QR code',
      'hi': 'इस QR कोड को साझा करें',
      'mr': 'हा QR कोड शेअर करा',
      'gu': 'આ QR કોડ શેર કરો',
    },
    'qr.shareError': {
      'en': 'Error sharing QR: {error}',
      'hi': 'QR साझा करने में त्रुटि: {error}',
      'mr': 'QR शेअर करताना त्रुटी: {error}',
      'gu': 'QR શેર કરતી વખતે ભૂલ: {error}',
    },
    'qr.generateError': {
      'en': 'Failed to generate QR: {error}',
      'hi': 'QR उत्पन्न करने में विफल: {error}',
      'mr': 'QR तयार करण्यात अयशस्वी: {error}',
      'gu': 'QR જનરેટ કરવામાં નિષ્ફળ: {error}',
    },
    'myLostReports.title': {
      'en': 'My Lost Reports',
      'hi': 'मेरी गुमशुदा रिपोर्टें',
      'mr': 'माझे हरवलेले अहवाल',
      'gu': 'મારી ગુમ થયેલી રિપોર્ટ્સ',
    },
    'myLostReports.status.open': {
      'en': 'Open',
      'hi': 'खुला',
      'mr': 'उघडा',
      'gu': 'ઓપન',
    },
    'myLostReports.status.matched': {
      'en': 'Matched',
      'hi': 'मिलान हुआ',
      'mr': 'जुळले',
      'gu': 'મેચ થયું',
    },
    'myLostReports.status.closed': {
      'en': 'Closed',
      'hi': 'बंद',
      'mr': 'बंद',
      'gu': 'બંધ',
    },
    'myLostReports.timeUnknown': {
      'en': 'Time not recorded',
      'hi': 'समय दर्ज नहीं',
      'mr': 'वेळ नोंदलेला नाही',
      'gu': 'સમય નોંધાયો નથી',
    },
    'myLostReports.card.unnamed': {
      'en': 'Unnamed report',
      'hi': 'बेनाम रिपोर्ट',
      'mr': 'नाव नसलेला अहवाल',
      'gu': 'બિનનામી રિપોર્ટ',
    },
    'myLostReports.card.ageApprox': {
      'en': 'Age ~{age}',
      'hi': 'उम्र ~{age}',
      'mr': 'वय ~{age}',
      'gu': 'ઉમર ~{age}',
    },
    'myLostReports.card.lastSeen': {
      'en': 'Last seen: {time}',
      'hi': 'अंतिम बार देखा गया: {time}',
      'mr': 'शेवटचे पाहिले: {time}',
      'gu': 'છેલ્લે જોવામાં આવ્યું: {time}',
    },
    'myLostReports.card.matchSuggested': {
      'en': 'Match suggested',
      'hi': 'मिलान सुझाया गया',
      'mr': 'जुळणी सुचवण्यात आली',
      'gu': 'મેચ સૂચવાયો',
    },
    'myLostReports.card.currentFacility': {
      'en': 'Current facility: {facility}',
      'hi': 'वर्तमान सुविधा: {facility}',
      'mr': 'सध्याची सुविधा: {facility}',
      'gu': 'વર્તમાન સુવિધા: {facility}',
    },
    'myLostReports.card.condition': {
      'en': 'Condition: {condition}',
      'hi': 'स्थिति: {condition}',
      'mr': 'स्थिती: {condition}',
      'gu': 'સ્થિતિ: {condition}',
    },
    'myLostReports.card.lastUpdated': {
      'en': 'Last updated: {time}',
      'hi': 'अंतिम अद्यतन: {time}',
      'mr': 'शेवटचे अद्यतन: {time}',
      'gu': 'છેલ્લું અપડેટ: {time}',
    },
    'myLostReports.error.title': {
      'en': 'Failed to load reports',
      'hi': 'रिपोर्ट लोड करने में विफल',
      'mr': 'अहवाल लोड करण्यात अयशस्वी',
      'gu': 'રિપોર્ટ્સ લોડ કરવામાં નિષ્ફળ',
    },
    'myLostReports.empty.title': {
      'en': 'No lost person reports yet',
      'hi': 'अभी तक कोई गुमशुदा रिपोर्ट नहीं',
      'mr': 'अजून हरवलेले अहवाल नाहीत',
      'gu': 'હજી સુધી કોઈ ગુમ થયેલી જાણ નથી',
    },
    'myLostReports.empty.subtitle': {
      'en':
          'When you report a lost family member, the status and suggested matches will appear here.',
      'hi':
          'जब आप किसी गुमशुदा सदस्य की रिपोर्ट करेंगे, तो स्थिति और सुझाए गए मिलान यहां दिखाई देंगे।',
      'mr':
          'तुम्ही हरवलेल्या कुटुंब सदस्याची नोंद केल्यावर स्थिती आणि सुचवलेली जुळणी येथे दिसतील.',
      'gu':
          'તમે ગુમ થયેલા પરિવાર સભ્યની જાણ કરશો ત્યારે સ્થિતિ અને સૂચવાયેલા મેળાવો અહીં દેખાશે.',
    },
    'reportFound.title': {
      'en': 'Report Found Person',
      'hi': 'मिले व्यक्ति की रिपोर्ट करें',
      'mr': 'सापडलेल्या व्यक्तीची नोंद करा',
      'gu': 'મળેલી વ્યક્તિની જાણ કરો',
    },
    'reportFound.help': {
      'en': 'Provide details to help families identify their loved one.',
      'hi': 'परिवारों को पहचान में मदद के लिए विवरण दें।',
      'mr': 'कुटुंबांना आपल्या प्रिय व्यक्तीची ओळख पटण्यासाठी तपशील द्या.',
      'gu': 'પરિવારોને તેમના પ્રિયજનો ઓળખવામાં મદદ કરવા વિગતો આપો.',
    },
    'reportFound.ageLabel': {
      'en': 'Approximate Age',
      'hi': 'लगभग आयु',
      'mr': 'अंदाजे वय',
      'gu': 'અંદાજિત ઉમર',
    },
    'reportFound.ageValidation': {
      'en': 'Enter a valid age',
      'hi': 'मान्य आयु दर्ज करें',
      'mr': 'वैध वय प्रविष्ट करा',
      'gu': 'માન્ય ઉમર દાખલ કરો',
    },
    'reportFound.genderLabel': {
      'en': 'Gender',
      'hi': 'लिंग',
      'mr': 'लिंग',
      'gu': 'લિંગ',
    },
    'reportFound.genderMale': {
      'en': 'Male',
      'hi': 'पुरुष',
      'mr': 'पुरुष',
      'gu': 'પુરુષ',
    },
    'reportFound.genderFemale': {
      'en': 'Female',
      'hi': 'महिला',
      'mr': 'महिला',
      'gu': 'સ્ત્રી',
    },
    'reportFound.genderOther': {
      'en': 'Other',
      'hi': 'अन्य',
      'mr': 'इतर',
      'gu': 'અન્ય',
    },
    'reportFound.genderUnknown': {
      'en': 'Unknown',
      'hi': 'अज्ञात',
      'mr': 'अज्ञात',
      'gu': 'અજ્ઞાત',
    },
    'reportFound.descriptionLabel': {
      'en': 'Description (clothing, distinguishing marks, accessories)',
      'hi': 'विवरण (कपड़े, पहचान चिह्न, एक्सेसरीज़)',
      'mr': 'वर्णन (कपडे, ओळख खुणा, अॅक्सेसरीज)',
      'gu': 'વર્ણન (કપડાં, ઓળખ ચિન્હો, ઍક્સેસરીઝ)',
    },
    'reportFound.descriptionValidation': {
      'en': 'Please describe the person that was found.',
      'hi': 'कृपया मिले व्यक्ति का विवरण दें।',
      'mr': 'कृपया सापडलेल्या व्यक्तीचे वर्णन करा.',
      'gu': 'કૃપા કરીને મળેલી વ્યક્તિનું વર્ણન કરો.',
    },
    'reportFound.conditionLabel': {
      'en': 'Current condition (optional)',
      'hi': 'वर्तमान स्थिति (वैकल्पिक)',
      'mr': 'सध्याची स्थिती (पर्यायी)',
      'gu': 'વર્તમાન સ્થિતિ (વૈકલ્પિક)',
    },
    'reportFound.conditionHint': {
      'en': 'Conscious, disoriented, unconscious, etc.',
      'hi': 'होश में, भ्रमित, बेहोश, आदि।',
      'mr': 'शुद्धीवर, गोंधळलेला, बेशुद्ध इ.',
      'gu': 'હોશમાં, ગૂંચવાયેલો, બેભાન વગેરે.',
    },
    'reportFound.hospitalLabel': {
      'en': 'Current hospital / camp (optional)',
      'hi': 'वर्तमान अस्पताल / शिविर (वैकल्पिक)',
      'mr': 'सध्याचे रुग्णालय / छावणी (पर्यायी)',
      'gu': 'વર્તમાન હોસ્પિટલ / કેમ્પ (વૈકલ્પિક)',
    },
    'reportFound.photoTitle': {
      'en': 'Photo',
      'hi': 'फोटो',
      'mr': 'फोटो',
      'gu': 'ફોટો',
    },
    'reportFound.photoPrompt': {
      'en': 'Upload a clear photo so families can confirm quickly.',
      'hi': 'एक स्पष्ट फोटो अपलोड करें ताकि परिवार जल्दी पुष्टि कर सकें।',
      'mr': 'कुटुंबांना लवकर खात्री करता यावी म्हणून स्पष्ट फोटो अपलोड करा.',
      'gu': 'પરિવારો ઝડપથી ખાતરી કરી શકે તે માટે સ્પષ્ટ ફોટો અપલોડ કરો.',
    },
    'reportFound.photoUploadedName': {
      'en': 'Uploaded photo',
      'hi': 'अपलोड की गई फोटो',
      'mr': 'अपलोड केलेला फोटो',
      'gu': 'અપલોડ કરેલો ફોટો',
    },
    'reportFound.camera': {
      'en': 'Camera',
      'hi': 'कैमरा',
      'mr': 'कॅमेरा',
      'gu': 'કૅમેરા',
    },
    'reportFound.gallery': {
      'en': 'Gallery',
      'hi': 'गैलरी',
      'mr': 'गॅलरी',
      'gu': 'ગૅલરી',
    },
    'reportFound.foundTime': {
      'en': 'Found time',
      'hi': 'मिलने का समय',
      'mr': 'सापडण्याची वेळ',
      'gu': 'મળેલી સમય',
    },
    'reportFound.edit': {
      'en': 'Edit',
      'hi': 'संपादित करें',
      'mr': 'संपादित करा',
      'gu': 'સંપાદિત કરો',
    },
    'reportFound.currentLocation': {
      'en': 'Current location',
      'hi': 'वर्तमान स्थान',
      'mr': 'सध्याचे स्थान',
      'gu': 'વર્તમાન સ્થાન',
    },
    'reportFound.useCurrent': {
      'en': 'Use current',
      'hi': 'वर्तमान का उपयोग करें',
      'mr': 'सध्याचे वापरा',
      'gu': 'વર્તમાન વાપરો',
    },
    'reportFound.submit': {
      'en': 'Submit Found Report',
      'hi': 'मिले व्यक्ति की रिपोर्ट जमा करें',
      'mr': 'सापडलेल्या व्यक्तीचा अहवाल सादर करा',
      'gu': 'મળેલી વ્યક્તિની જાણ કરો',
    },
    'reportFound.thankYou': {
      'en':
          'Suggested matches will appear for admins. Thank you for helping reconnect families.',
      'hi':
          'प्रशासकों के लिए सुझाए गए मिलान दिखाई देंगे। परिवारों को मिलाने में मदद के लिए धन्यवाद।',
      'mr':
          'प्रशासकांसाठी सुचवलेली जुळणी दिसतील. कुटुंबांना पुन्हा जोडण्यास मदत केल्याबद्दल धन्यवाद.',
      'gu':
          'એડમિન માટે સૂચવાયેલા મેળાવો દેખાશે. પરિવારોને ફરી જોડવામાં મદદ માટે આભાર.',
    },
    'reportFound.locationEnable': {
      'en': 'Enable location services to capture current location.',
      'hi': 'वर्तमान स्थान प्राप्त करने के लिए स्थान सेवाएँ सक्षम करें।',
      'mr': 'सध्याचे स्थान मिळवण्यासाठी स्थान सेवा सक्षम करा.',
      'gu': 'વર્તમાન સ્થાન મેળવવા માટે સ્થાન સેવાઓ સક્રિય કરો.',
    },
    'reportFound.locationPermissionDenied': {
      'en': 'Location permission denied.',
      'hi': 'स्थान अनुमति अस्वीकृत।',
      'mr': 'स्थान परवानगी नाकारली.',
      'gu': 'સ્થાન પરવાનગી નકારી.',
    },
    'reportFound.locationPermissionForever': {
      'en':
          'Location permission permanently denied. Please enable from settings.',
      'hi':
          'स्थान अनुमति स्थायी रूप से अस्वीकृत है। कृपया सेटिंग्स से सक्षम करें।',
      'mr':
          'स्थान परवानगी कायमस्वरूपी नाकारली आहे. कृपया सेटिंगमध्ये सक्षम करा.',
      'gu':
          'સ્થાન પરવાનગી કાયમી રીતે નકારી દેવામાં આવી છે. કૃપા કરીને સેટિંગ્સમાં સક્રિય કરો.',
    },
    'reportFound.locationError': {
      'en': 'Failed to access location: {error}',
      'hi': 'स्थान तक पहुँचने में विफल: {error}',
      'mr': 'स्थानावर प्रवेश करण्यात अयशस्वी: {error}',
      'gu': 'સ્થાન પ્રાપ્ત કરવામાં નિષ્ફળ: {error}',
    },
    'reportFound.photoUploadFailed': {
      'en': 'Photo upload failed. Please try again.',
      'hi': 'फोटो अपलोड विफल। कृपया पुनः प्रयास करें।',
      'mr': 'फोटो अपलोड अयशस्वी. कृपया पुन्हा प्रयत्न करा.',
      'gu': 'ફોટો અપલોડ નિષ્ફળ. કૃપા કરીને ફરી પ્રયાસ કરો.',
    },
    'reportFound.photoSelectFailed': {
      'en': 'Unable to select photo: {error}',
      'hi': 'फोटो चयन असफल: {error}',
      'mr': 'फोटो निवडता आला नाही: {error}',
      'gu': 'ફોટો પસંદ કરી શક્યા નથી: {error}',
    },
    'reportFound.photoRequired': {
      'en': 'A clear photo is required to help families match.',
      'hi': 'परिवारों को मिलान में मदद के लिए एक स्पष्ट फोटो आवश्यक है।',
      'mr': 'कुटुंबांना जुळणीमध्ये मदत करण्यासाठी स्पष्ट फोटो आवश्यक आहे.',
      'gu': 'પરિવારોને મેળવામાં મદદ માટે સ્પષ્ટ ફોટો જરૂરી છે.',
    },
    'reportFound.locationRequired': {
      'en': 'Please capture current location so teams can reach the facility.',
      'hi': 'कृपया वर्तमान स्थान प्राप्त करें ताकि टीमें सुविधा तक पहुँच सकें।',
      'mr': 'कृपया सध्याचे स्थान घ्या जेणेकरून पथके सुविधेपर्यंत पोहोचू शकतील.',
      'gu': 'કૃપા કરીને વર્તમાન સ્થાન મેળવો જેથી ટીમો સુવિધાએ પહોંચી શકે.',
    },
    'reportFound.submitSuccess': {
      'en': 'Found person report submitted. Matching engine will review.',
      'hi': 'मिले व्यक्ति की रिपोर्ट जमा हो गई। मिलान इंजन समीक्षा करेगा।',
      'mr':
          'सापडलेल्या व्यक्तीचा अहवाल सादर झाला. जुळणी इंजिन त्याची समीक्षा करेल.',
      'gu': 'મળેલી વ્યક્તિનો રિપોર્ટ સબમિટ થયો. મેચિંગ એન્જિન સમીક્ષા કરશે.',
    },
    'reportFound.submitFailure': {
      'en': 'Failed to submit found person report.',
      'hi': 'मिले व्यक्ति की रिपोर्ट जमा करने में विफल।',
      'mr': 'सापडलेल्या व्यक्तीचा अहवाल सादर करण्यात अयशस्वी.',
      'gu': 'મળેલી વ્યક્તિનો રિપોર્ટ સબમિટ કરવામાં નિષ્ફળ.',
    },
    'reportFound.submitError': {
      'en': 'Unexpected error: {error}',
      'hi': 'अप्रत्याशित त्रुटि: {error}',
      'mr': 'अनपेक्षित त्रुटी: {error}',
      'gu': 'અનપેક્ષિત ભૂલ: {error}',
    },
    'reportFound.locationNotCaptured': {
      'en': 'Location not captured',
      'hi': 'स्थान रिकॉर्ड नहीं हुआ',
      'mr': 'स्थान नोंदलेले नाही',
      'gu': 'સ્થાન પકડાયું નથી',
    },
    'reportFound.datePicker.help': {
      'en': 'Select found time',
      'hi': 'मिलने का समय चुनें',
      'mr': 'सापडल्याची वेळ निवडा',
      'gu': 'મળેલી સમય પસંદ કરો',
    },
    'reportFound.datePicker.cancel': {
      'en': 'Cancel',
      'hi': 'रद्द करें',
      'mr': 'रद्द करा',
      'gu': 'રદ કરો',
    },
    'reportFound.datePicker.confirm': {
      'en': 'Select',
      'hi': 'चयन करें',
      'mr': 'निवडा',
      'gu': 'પસંદ કરો',
    },
    'uploadDocument.title': {
      'en': 'Upload Document',
      'hi': 'दस्तावेज़ अपलोड करें',
      'mr': 'दस्तावेज अपलोड करा',
      'gu': 'દસ્તાવેજ અપલોડ કરો',
    },
    'uploadDocument.field.titleLabel': {
      'en': 'Document Title',
      'hi': 'दस्तावेज़ शीर्षक',
      'mr': 'दस्तावेज शीर्षक',
      'gu': 'દસ્તાવેજ શીર્ષક',
    },
    'uploadDocument.field.categoryLabel': {
      'en': 'Category',
      'hi': 'श्रेणी',
      'mr': 'वर्ग',
      'gu': 'શ્રેણી',
    },
    'uploadDocument.field.dateLabel': {
      'en': 'Document Date',
      'hi': 'दस्तावेज़ की तारीख',
      'mr': 'दस्तावेज दिनांक',
      'gu': 'દસ્તાવેજ તારીખ',
    },
    'uploadDocument.field.dateHint': {
      'en': 'Select date when document was created',
      'hi': 'दस्तावेज़ बनाने की तारीख चुनें',
      'mr': 'दस्तावेज तयार झाल्याची तारीख निवडा',
      'gu': 'દસ્તાવેજ બનાવવાનો દિવસ પસંદ કરો',
    },
    'uploadDocument.field.notesLabel': {
      'en': 'Notes (optional)',
      'hi': 'नोट्स (वैकल्पिक)',
      'mr': 'नोंदी (पर्यायी)',
      'gu': 'નોંધો (વૈકલ્પિક)',
    },
    'uploadDocument.field.filePlaceholder': {
      'en': 'No file selected / photo captured',
      'hi': 'कोई फ़ाइल चयनित नहीं / फोटो कैप्चर नहीं',
      'mr': 'फाइल निवडलेली नाही / फोटो घेतलेला नाही',
      'gu': 'કોઈ ફાઇલ પસંદ નથી / ફોટો લેવામાં આવ્યો નથી',
    },
    'uploadDocument.button.removeFile': {
      'en': 'Remove selected file',
      'hi': 'चयनित फ़ाइल हटाएँ',
      'mr': 'निवडलेली फाइल काढा',
      'gu': 'પસંદ કરેલી ફાઇલ દૂર કરો',
    },
    'uploadDocument.deleteFile.title': {
      'en': 'Delete File',
      'hi': 'फ़ाइल हटाएं',
      'mr': 'फाइल हटवा',
      'gu': 'ફાઇલ કાઢી નાખો',
    },
    'uploadDocument.deleteFile.message': {
      'en':
          'Are you sure you want to delete "{fileName}"? This action cannot be undone.',
      'hi':
          'क्या आप वाकई "{fileName}" को हटाना चाहते हैं? यह कार्रवाई पूर्ववत नहीं की जा सकती।',
      'mr':
          'तुम्हाला खरोखर "{fileName}" हटवायची आहे का? ही क्रिया पूर्ववत करता येत नाही.',
      'gu':
          'શું તમે ખરેખર "{fileName}" કાઢી નાખવા માંગો છો? આ ક્રિયા પૂર્વવત્ કરી શકાતી નથી.',
    },
    'uploadDocument.button.upload': {
      'en': 'Upload Document',
      'hi': 'दस्तावेज़ अपलोड करें',
      'mr': 'दस्तावेज अपलोड करा',
      'gu': 'દસ્તાવેજ અપલોડ કરો',
    },
    'uploadDocument.progressLabel': {
      'en': 'Uploading... {percent}%',
      'hi': 'अपलोड हो रहा है... {percent}%',
      'mr': 'अपलोड होत आहे... {percent}%',
      'gu': 'અપલોડ થઈ રહ્યું છે... {percent}%',
    },
    'uploadDocument.error.missingFields': {
      'en': '⚠️ Fill all fields and select a file',
      'hi': '⚠️ सभी फ़ील्ड भरें और एक फ़ाइल चुनें',
      'mr': '⚠️ सर्व फील्ड भरा आणि फाइल निवडा',
      'gu': '⚠️ બધા ક્ષેત્ર ભરો અને ફાઇલ પસંદ કરો',
    },
    'uploadDocument.error.uploadFailed': {
      'en': '❌ Upload failed',
      'hi': '❌ अपलोड विफल',
      'mr': '❌ अपलोड अयशस्वी',
      'gu': '❌ અપલોડ નિષ્ફળ',
    },
    'uploadDocument.datePicker.help': {
      'en': 'Select document date',
      'hi': 'दस्तावेज़ की तारीख चुनें',
      'mr': 'दस्तावेज दिनांक निवडा',
      'gu': 'દસ્તાવેજ તારીખ પસંદ કરો',
    },
    'uploadDocument.datePicker.cancel': {
      'en': 'Cancel',
      'hi': 'रद्द करें',
      'mr': 'रद्द करा',
      'gu': 'રદ કરો',
    },
    'uploadDocument.datePicker.confirm': {
      'en': 'Select',
      'hi': 'चयन करें',
      'mr': 'निवडा',
      'gu': 'પસંદ કરો',
    },
    'qrAccess.title': {
      'en': 'How QR Access Works',
      'hi': 'QR एक्सेस कैसे काम करता है',
      'mr': 'QR प्रवेश कसा कार्य करतो',
      'gu': 'QR ઍક્સેસ કેવી રીતે કાર્ય કરે છે',
    },
    'qrAccess.heading': {
      'en': '📌 How QR Access Works',
      'hi': '📌 QR एक्सेस कैसे काम करता है',
      'mr': '📌 QR प्रवेश कसा कार्य करतो',
      'gu': '📌 QR ઍક્સેસ કેવી રીતે કાર્ય કરે છે',
    },
    'qrAccess.intro': {
      'en':
          'QR access allows you to securely share or retrieve your documents without manually entering details. Here\'s how it works:',
      'hi':
          'QR एक्सेस आपको विवरण मैन्युअली दर्ज किए बिना अपने दस्तावेज़ों को सुरक्षित रूप से साझा या प्राप्त करने की अनुमति देता है। यह इस तरह काम करता है:',
      'mr':
          'QR प्रवेश तुम्हाला तुमचे तपशील हाताने न भरता दस्तावेज सुरक्षितपणे शेअर किंवा प्राप्त करण्याची परवानगी देतो. हे कसे कार्य करते ते येथे आहे:',
      'gu':
          'QR ઍક્સેસ તમને વિગતો હાથથી દાખલ કર્યા વગર તમારી દસ્તાવેજો સુરક્ષિત રીતે શેર અથવા મેળવવાની મંજૂરી આપે છે. તે આ રીતે કાર્ય કરે છે:',
    },
    'qrAccess.step1.title': {
      'en': '1. Generate a QR Code',
      'hi': '1. QR कोड उत्पन्न करें',
      'mr': '1. QR कोड तयार करा',
      'gu': '1. QR કોડ જનરેટ કરો',
    },
    'qrAccess.step1.body': {
      'en':
          '• When you upload a document, the app can generate a unique QR code linked to that file.\n• This QR code acts like a digital key.',
      'hi':
          '• जब आप कोई दस्तावेज़ अपलोड करते हैं, तो ऐप उससे जुड़ा एक अद्वितीय QR कोड बना सकता है।\n• यह QR कोड एक डिजिटल कुंजी की तरह काम करता है।',
      'mr':
          '• जेव्हा तुम्ही दस्तावेज अपलोड करता, तेव्हा अॅप त्या फाइलशी संबंधित एक अद्वितीय QR कोड तयार करू शकतो.\n• हा QR कोड डिजिटल की प्रमाणे कार्य करतो.',
      'gu':
          '• જ્યારે તમે દસ્તાવેજ અપલોડ કરો છો, ત્યારે એપ તે ફાઇલ સાથે જોડાયેલ અનન્ય QR કોડ જનરેટ કરી શકે છે.\n• આ QR કોડ ડિજિટલ કી તરીકે કાર્ય કરે છે.',
    },
    'qrAccess.step2.title': {
      'en': '2. Scan the QR Code',
      'hi': '2. QR कोड स्कैन करें',
      'mr': '2. QR कोड स्कॅन करा',
      'gu': '2. QR કોડ સ્કેન કરો',
    },
    'qrAccess.step2.body': {
      'en':
          '• Another user (or you, on a different device) can scan the QR code using the app\'s built-in scanner.\n• Scanning instantly retrieves the file details from the secure server.',
      'hi':
          '• कोई अन्य उपयोगकर्ता (या आप, किसी दूसरे डिवाइस पर) ऐप के बिल्ट-इन स्कैनर का उपयोग करके QR कोड स्कैन कर सकता है।\n• स्कैन करने से सुरक्षित सर्वर से फ़ाइल विवरण तुरंत प्राप्त हो जाते हैं।',
      'mr':
          '• दुसरा वापरकर्ता (किंवा तुम्ही, वेगळ्या डिव्हाइसवर) अॅपच्या अंगभूत स्कॅनरचा वापर करून QR कोड स्कॅन करू शकतो.\n• स्कॅन केल्याने सुरक्षित सर्व्हरवरून फाइल तपशील त्वरित मिळतात.',
      'gu':
          '• બીજો વપરાશકર્તા (અથવા તમે, બીજા ઉપકરણ પર) એપના બિલ્ટ-ઇન સ્કેનરનો ઉપયોગ કરીને QR કોડ સ્કેન કરી શકે છે.\n• સ્કેનિંગ તુરંત સુરક્ષિત સર્વર પરથી ફાઇલ વિગતો મેળવશે.',
    },
    'qrAccess.step3.title': {
      'en': '3. Access Control',
      'hi': '3. एक्सेस नियंत्रण',
      'mr': '3. प्रवेश नियंत्रण',
      'gu': '3. ઍક્સેસ નિયંત્રણ',
    },
    'qrAccess.step3.body': {
      'en':
          '• The QR code is tied to your account/document, so only people with the code can access it.\n• Optionally, QR codes can be time-limited or password-protected for extra security.',
      'hi':
          '• QR कोड आपके खाते/दस्तावेज़ से जुड़ा होता है, इसलिए केवल कोड वाले लोग ही इसे एक्सेस कर सकते हैं।\n• अतिरिक्त सुरक्षा के लिए QR कोड समय-सीमा या पासवर्ड-संरक्षित भी हो सकते हैं।',
      'mr':
          '• QR कोड तुमच्या खात्याशी/दस्तावेजाशी जोडलेला असतो, त्यामुळे फक्त कोड असलेले लोकच त्याला प्रवेश करू शकतात.\n• अतिरिक्त सुरक्षेसाठी QR कोड वेळ-सीमित किंवा पासवर्ड संरक्षित असू शकतात.',
      'gu':
          '• QR કોડ તમારા ખાતા/દસ્તાવેજ સાથે જોડાયેલ છે, તેથી ફક્ત કોડ ધરાવતા લોકો જ તેને ઍક્સેસ કરી શકે છે.\n• વધારાની સુરક્ષા માટે QR કોડ સમયમર્યાદિત અથવા પાસવર્ડથી સુરક્ષિત હોઈ શકે છે.',
    },
    'qrAccess.step4.title': {
      'en': '4. Use Cases',
      'hi': '4. उपयोग परिदृश्य',
      'mr': '4. उपयोग प्रकरणे',
      'gu': '4. ઉપયોગ કેસ',
    },
    'qrAccess.step4.body': {
      'en':
          '• Quickly open your medical reports at a hospital.\n• Share bills or prescriptions with family or doctors without sending files manually.\n• Access your own documents on a new device just by scanning your saved QR.',
      'hi':
          '• अस्पताल में अपने मेडिकल रिपोर्ट तेजी से खोलें।\n• बिल या प्रिस्क्रिप्शन परिवार या डॉक्टरों के साथ मैन्युअल रूप से फ़ाइल भेजे बिना साझा करें।\n• केवल संग्रहीत QR स्कैन करके किसी नए डिवाइस पर अपने दस्तावेज़ों तक पहुँचें।',
      'mr':
          '• रुग्णालयात तुमचे वैद्यकीय अहवाल पटकन उघडा.\n• बिल किंवा प्रिस्क्रिप्शन फाइल हाताने न पाठवता कुटुंबीय किंवा डॉक्टरांसोबत शेअर करा.\n• सेव्ह केलेला QR स्कॅन करून नवीन डिव्हाइसवर तुमच्या दस्तावेजांवर प्रवेश करा.',
      'gu':
          '• હોસ્પિટલમાં તમારી મેડિકલ રિપોર્ટ્સ ઝડપથી ખોલો.\n• ફાઇલો હાથથી મોકલ્યા વિના બિલ્સ અથવા પ્રિસ્ક્રિપ્શન પરિવાર અથવા ડોક્ટરો સાથે શેર કરો.\n• ફક્ત સાચવેલ QR સ્કેન કરીને નવા ઉપકરણ પર તમારા દસ્તાવેજો ઍક્સેસ કરો.',
    },
    'qrAccess.summary': {
      'en':
          '⚡ In short: QR = Quick + Secure + Hassle-free access to your digital vault.',
      'hi':
          '⚡ संक्षेप में: QR = तेज + सुरक्षित + परेशानी मुक्त एक्सेस आपके डिजिटल वॉल्ट तक।',
      'mr':
          '⚡ थोडक्यात: QR = जलद + सुरक्षित + त्रासमुक्त प्रवेश तुमच्या डिजिटल व्हॉल्टमध्ये.',
      'gu':
          '⚡ ટૂંકમાં: QR = ઝડપી + સુરક્ષિત + મુશ્કેલી રહિત ઍક્સેસ તમારા ડિજિટલ વોલ્ટ સુધી.',
    },
    'profileSwitcher.title': {
      'en': 'Switch Profile',
      'hi': 'प्रोफ़ाइल बदलें',
      'mr': 'प्रोफाइल बदला',
      'gu': 'પ્રોફાઇલ બદલો',
    },
    'profileSwitcher.current': {
      'en': 'Current',
      'hi': 'वर्तमान',
      'mr': 'सध्याचे',
      'gu': 'હાલનું',
    },
    'profileSwitcher.empty.title': {
      'en': 'No linked profiles',
      'hi': 'कोई लिंक्ड प्रोफ़ाइल नहीं',
      'mr': 'लिंक प्रोफाइल नाहीत',
      'gu': 'કોઈ જોડાયેલ પ્રોફાઇલ નથી',
    },
    'profileSwitcher.empty.subtitle': {
      'en': 'Add profiles to switch between them',
      'hi': 'प्रोफ़ाइल जोड़ें ताकि उनके बीच स्विच कर सकें',
      'mr': 'प्रोफाइल जोडा जेणेकरून त्यांच्यात स्विच करता येईल',
      'gu': 'પ્રોફાઇલ્સ ઉમેરો જેથી તેમના વચ્ચે સ્વિચ કરી શકાય',
    },
    'profileSwitcher.switchSuccess': {
      'en': '✅ Switched to {name}',
      'hi': '✅ {name} पर स्विच किया गया',
      'mr': '✅ {name} वर स्विच केले',
      'gu': '✅ {name} પર સ્વિચ થયું',
    },
    'profileSwitcher.switchFailed': {
      'en': 'Failed to switch profile',
      'hi': 'प्रोफ़ाइल बदलने में विफल',
      'mr': 'प्रोफाइल बदलण्यात अयशस्वी',
      'gu': 'પ્રોફાઇલ બદલવામાં નિષ્ફળ',
    },
    'profileSwitcher.switchError': {
      'en': 'Error: {error}',
      'hi': 'त्रुटि: {error}',
      'mr': 'त्रुटी: {error}',
      'gu': 'ભૂલ: {error}',
    },
    'profileSwitcher.unknown': {
      'en': 'Unknown',
      'hi': 'अज्ञात',
      'mr': 'अज्ञात',
      'gu': 'અજ્ઞાત',
    },
    'profileSwitcher.password.title': {
      'en': 'Switch to {name}',
      'hi': '{name} पर स्विच करें',
      'mr': '{name} वर स्विच करा',
      'gu': '{name} પર સ્વિચ કરો',
    },
    'profileSwitcher.password.prompt': {
      'en': 'Enter password for {name}:',
      'hi': '{name} का पासवर्ड दर्ज करें:',
      'mr': '{name} साठी पासवर्ड प्रविष्ट करा:',
      'gu': '{name} માટે પાસવર્ડ દાખલ કરો:',
    },
    'profileSwitcher.password.label': {
      'en': 'Password',
      'hi': 'पासवर्ड',
      'mr': 'पासवर्ड',
      'gu': 'પાસવર્ડ',
    },
    'profileSwitcher.password.hint': {
      'en': 'Enter password',
      'hi': 'पासवर्ड दर्ज करें',
      'mr': 'पासवर्ड प्रविष्ट करा',
      'gu': 'પાસવર્ડ દાખલ કરો',
    },
    'profileSwitcher.password.switch': {
      'en': 'Switch',
      'hi': 'बदलें',
      'mr': 'स्विच करा',
      'gu': 'સ્વિચ કરો',
    },
    'profile.field.name': {
      'en': 'Name',
      'hi': 'नाम',
      'mr': 'नाव',
      'gu': 'નામ',
    },
    'profile.field.email': {
      'en': 'Email',
      'hi': 'ईमेल',
      'mr': 'ईमेल',
      'gu': 'ઈમેલ',
    },
    'profile.field.mobile': {
      'en': 'Mobile',
      'hi': 'मोबाइल',
      'mr': 'मोबाइल',
      'gu': 'મોબાઈલ',
    },
    'profile.field.aadhaar': {
      'en': 'Aadhaar',
      'hi': 'आधार',
      'mr': 'आधार',
      'gu': 'આધાર',
    },
    'profile.field.dateOfBirth': {
      'en': 'Date of Birth',
      'hi': 'जन्म तिथि',
      'mr': 'जन्मतारीख',
      'gu': 'જન્મ તારીખ',
    },
    'profile.field.age': {
      'en': 'Age',
      'hi': 'आयु',
      'mr': 'वय',
      'gu': 'વય',
    },
    'profile.field.gender': {
      'en': 'Gender',
      'hi': 'लिंग',
      'mr': 'लिंग',
      'gu': 'લિંગ',
    },
    'profile.field.bloodType': {
      'en': 'Blood Type',
      'hi': 'रक्त समूह',
      'mr': 'रक्त गट',
      'gu': 'રક્તનો પ્રકાર',
    },
    'profile.field.height': {
      'en': 'Height',
      'hi': 'ऊंचाई',
      'mr': 'उंची',
      'gu': 'ઉંચાઈ',
    },
    'profile.field.weight': {
      'en': 'Weight',
      'hi': 'वजन',
      'mr': 'वजन',
      'gu': 'વજન',
    },
    'profile.field.allergies': {
      'en': 'Allergies',
      'hi': 'एलर्जी',
      'mr': 'अॅलर्जी',
      'gu': 'ઍલર્જી',
    },
    'profile.field.lastVisit': {
      'en': 'Last Visit',
      'hi': 'अंतिम मुलाकात',
      'mr': 'शेवटची भेट',
      'gu': 'છેલ્લી મુલાકાત',
    },
    'profile.field.nextAppointment': {
      'en': 'Next Appointment',
      'hi': 'अगली नियुक्ति',
      'mr': 'पुढील भेट',
      'gu': 'આગામી મુલાકાત',
    },
    'profile.field.emergencyName': {
      'en': 'Emergency Contact Name',
      'hi': 'आपातकालीन संपर्क नाम',
      'mr': 'आपत्कालीन संपर्क नाव',
      'gu': 'તાકીદનો સંપર્ક નામ',
    },
    'profile.field.emergencyRelationship': {
      'en': 'Emergency Contact Relationship',
      'hi': 'आपातकालीन संपर्क संबंध',
      'mr': 'आपत्कालीन संपर्क नाते',
      'gu': 'તાકીદના સંપર્કનો સંબંધ',
    },
    'profile.field.emergencyPhone': {
      'en': 'Emergency Contact Phone',
      'hi': 'आपातकालीन संपर्क फोन',
      'mr': 'आपत्कालीन संपर्क फोन',
      'gu': 'તાકીદનો સંપર્ક ફોન',
    },
    'privacy.title': {
      'en': 'Privacy Policy',
      'hi': 'गोपनीयता नीति',
      'mr': 'गोपनीयता धोरण',
      'gu': 'ગોપનીયતા નીતિ',
    },
    'privacy.showUpdates': {
      'en': 'Show Updates',
      'hi': 'अपडेट दिखाएं',
      'mr': 'अपडेट दाखवा',
      'gu': 'અપડેટ બતાવો',
    },
    'privacy.banner.accepted': {
      'en': 'Privacy Policy Accepted (v{version})',
      'hi': 'गोपनीयता नीति स्वीकार की गई (संस्करण {version})',
      'mr': 'गोपनीयता धोरण स्वीकारले (आवृत्ती {version})',
      'gu': 'ગોપનીયતા નીતિ સ્વીકારવામાં આવી (આવૃત્તિ {version})',
    },
    'privacy.banner.pending': {
      'en': 'Please review and accept our Privacy Policy',
      'hi': 'कृपया हमारी गोपनीयता नीति की समीक्षा करें और स्वीकार करें',
      'mr': 'कृपया आमच्या गोपनीयता धोरणाचा आढावा घ्या आणि स्वीकारा',
      'gu': 'કૃપા કરીને અમારી ગોપનીયતા નીતિની સમીક્ષા કરો અને સ્વીકારો',
    },
    'privacy.acceptButton': {
      'en': 'Accept Privacy Policy',
      'hi': 'गोपनीयता नीति स्वीकारें',
      'mr': 'गोपनीयता धोरण स्वीकारा',
      'gu': 'ગોપનીયતા નીતિ સ્વીકારો',
    },
    'privacy.understandButton': {
      'en': 'I Understand',
      'hi': 'मैं समझता हूँ',
      'mr': 'मी समजतो',
      'gu': 'હું સમજું છું',
    },
    'privacy.acceptedSuccess': {
      'en': 'Privacy Policy accepted successfully',
      'hi': 'गोपनीयता नीति सफलतापूर्वक स्वीकार की गई',
      'mr': 'गोपनीयता धोरण यशस्वीरित्या स्वीकारले',
      'gu': 'ગોપનીયતા નીતિ સફળતાપૂર્વક સ્વીકારવામાં આવી',
    },
    'privacy.versionLabel': {
      'en': 'Version: {version}',
      'hi': 'संस्करण: {version}',
      'mr': 'आवृत्ती: {version}',
      'gu': 'આવૃત્તિ: {version}',
    },
    'privacy.updatesTitle': {
      'en': 'Recent Privacy Policy Updates',
      'hi': 'हाल के गोपनीयता नीति अपडेट',
      'mr': 'अलीकडील गोपनीयता धोरण अद्यतने',
      'gu': 'તાજેતરના ગોપનીયતા નીતિ સુધારા',
    },
    'common.confirm': {
      'en': 'Confirm',
      'hi': 'पुष्टि करें',
      'mr': 'पुष्टी करा',
      'gu': 'પુષ્ટિ કરો',
    },
    'common.add': {
      'en': 'Add',
      'hi': 'जोड़ें',
      'mr': 'जोडा',
      'gu': 'ઉમેરો',
    },
    'common.save': {
      'en': 'Save',
      'hi': 'सहेजें',
      'mr': 'जतन करा',
      'gu': 'સાચવો',
    },
    'common.update': {
      'en': 'Update',
      'hi': 'अपडेट करें',
      'mr': 'अद्यतन करा',
      'gu': 'અપડેટ કરો',
    },
    'common.edit': {
      'en': 'Edit',
      'hi': 'संपादित करें',
      'mr': 'संपादित करा',
      'gu': 'સંપાદિત કરો',
    },
    'common.close': {
      'en': 'Close',
      'hi': 'बंद करें',
      'mr': 'बंद करा',
      'gu': 'બંધ કરો',
    },
    'terms.title': {
      'en': 'Terms and Conditions',
      'hi': 'नियम और शर्तें',
      'mr': 'नियम आणि अटी',
      'gu': 'નિયમો અને શરતો',
    },
    'terms.heading': {
      'en': 'Terms and Conditions',
      'hi': 'नियम और शर्तें',
      'mr': 'नियम आणि अटी',
      'gu': 'નિયમો અને શરતો',
    },
    'terms.lastUpdated': {
      'en': 'Last updated: {date}',
      'hi': 'अंतिम अपडेट: {date}',
      'mr': 'शेवटचे अद्यतन: {date}',
      'gu': 'છેલ્લું અપડેટ: {date}',
    },
    'terms.summary': {
      'en':
          'By using Medical Vault, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
      'hi':
          'मेडिकल वॉल्ट का उपयोग करके, आप स्वीकार करते हैं कि आपने इन नियमों और शर्तों को पढ़ा, समझा और उनसे बंधे रहने के लिए सहमत हैं।',
      'mr':
          'मेडिकल व्हॉल्ट वापरून, तुम्ही हे नियम आणि अटी वाचले, समजले आणि त्यांचे पालन करण्यास सहमत आहात असे मान्य करता.',
      'gu':
          'મેડિકલ વોલ્ટનો ઉપયોગ કરીને, તમે સ્વીકારો છો કે તમે આ નિયમો અને શરતો વાંચ્યા છે, સમજે છે અને તેમનું પાલન કરવા સંમત છો.',
    },
    'termsPage.section1.title': {
      'en': '1. Acceptance of Terms',
      'hi': '1. नियमों का स्वीकृति',
      'mr': '1. अटींची स्वीकृती',
      'gu': '1. શરતોની સ્વીકાર્યતા',
    },
    'termsPage.section1.body': {
      'en':
          'By accessing and using the Medical Vault application, you accept and agree to be bound by the terms and provision of this agreement.',
      'hi':
          'मेडिकल वॉल्ट एप्लिकेशन का उपयोग करके, आप इस समझौते की शर्तों और प्रावधानों से बंधे रहने के लिए सहमत होते हैं।',
      'mr':
          'मेडिकल व्हॉल्ट अनुप्रयोगात प्रवेश करून आणि वापरून, तुम्ही या कराराच्या अटी आणि तरतुदींना बांधील राहण्यास सहमत आहात.',
      'gu':
          'મેડિકલ વોલ્ટ ઍપ્લિકેશનનો ઉપયોગ કરીને, તમે આ કરારની શરતો અને જોગવાઈઓનું પાલન કરવા સંમત થાઓ છો.',
    },
    'termsPage.section2.title': {
      'en': '2. Use License',
      'hi': '2. उपयोग लाइसेंस',
      'mr': '2. वापर परवाना',
      'gu': '2. ઉપયોગ લાઇસન્સ',
    },
    'termsPage.section2.body': {
      'en':
          'Permission is granted to temporarily download one copy of Medical Vault per device for personal, non-commercial transitory viewing only. This is the grant of a license, not a transfer of title.',
      'hi':
          'व्यक्तिगत, गैर-व्यावसायिक अस्थायी उपयोग के लिए प्रति डिवाइस मेडिकल वॉल्ट की एक प्रति डाउनलोड करने की अनुमति दी जाती है। यह लाइसेंस का अनुदान है, शीर्षक का हस्तांतरण नहीं।',
      'mr':
          'वैयक्तिक, गैर-व्यावसायिक तात्पुरत्या वापरासाठी प्रति डिव्हाइस मेडिकल व्हॉल्टची एक प्रति डाउनलोड करण्यास अनुमती दिली जाते. हा परवाना देणे आहे, शीर्षकाचा हस्तांतरण नाही.',
      'gu':
          'વ્યક્તિગત, ગેર-વ્યાપારી સમયસર ઉપયોગ માટે પ્રતિ ઉપકરણ મેડિકલ વોલ્ટની એક નકલ ડાઉનલોડ કરવાની મંજૂરી આપવામાં આવે છે. આ લાઇસન્સનું પ્રદાન છે, ટાઇટલનું ટ્રાન્સફર નથી.',
    },
    'termsPage.section3.title': {
      'en': '3. Medical Information Disclaimer',
      'hi': '3. चिकित्सा सूचना अस्वीकरण',
      'mr': '3. वैद्यकीय माहिती अस्वीकरण',
      'gu': '3. તબીબી માહિતી નિષ્કર્ષ',
    },
    'termsPage.section3.body': {
      'en':
          'The Medical Vault application helps you store and organize medical records but is not a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of qualified health providers for medical concerns.',
      'hi':
          'मेडिकल वॉल्ट एप्लिकेशन आपकी चिकित्सा रिकॉर्ड को संग्रहीत और व्यवस्थित करने में मदद करता है लेकिन यह पेशेवर चिकित्सा सलाह, निदान या उपचार का विकल्प नहीं है। हमेशा योग्य स्वास्थ्य प्रदाताओं की सलाह लें।',
      'mr':
          'मेडिकल व्हॉल्ट अनुप्रयोग तुम्हाला वैद्यकीय नोंदी संग्रहित आणि व्यवस्थित करण्यास मदत करतो परंतु व्यावसायिक वैद्यकीय सल्ला, निदान किंवा उपचारांचा पर्याय नाही. वैद्यकीय चिंतेसाठी नेहमी पात्र आरोग्य सेवा प्रदात्यांचा सल्ला घ्या.',
      'gu':
          'મેડિકલ વોલ્ટ ઍપ્લિકેશન તમને તબીબી રેકોર્ડ્સ સંગ્રહિત અને ગોઠવવામાં મદદ કરે છે, પરંતુ તે વ્યાવસાયિક તબીબી સલાહ, નિદાન અથવા સારવારનો વિકલ્પ નથી. હંમેશાં લાયક હેલ્થકેર પ્રદાતાઓની સલાહ લો.',
    },
    'termsPage.section4.title': {
      'en': '4. Data Security and Privacy',
      'hi': '4. डेटा सुरक्षा और गोपनीयता',
      'mr': '4. डेटा सुरक्षा आणि गोपनीयता',
      'gu': '4. ડેટા સુરક્ષા અને ગોપનીયતા',
    },
    'termsPage.section4.body': {
      'en':
          'We are committed to protecting your personal and medical information. All data is encrypted and stored securely. We do not share your medical information with third parties without your explicit consent.',
      'hi':
          'हम आपकी व्यक्तिगत और चिकित्सा जानकारी की सुरक्षा के लिए प्रतिबद्ध हैं। सभी डेटा एन्क्रिप्टेड और सुरक्षित रूप से संग्रहीत है। हम आपकी स्पष्ट सहमति के बिना आपकी जानकारी साझा नहीं करते।',
      'mr':
          'आम्ही तुमची वैयक्तिक आणि वैद्यकीय माहिती संरक्षित करण्यास कटिबद्ध आहोत. सर्व डेटा एन्क्रिप्टेड असून सुरक्षितपणे संग्रहित केलेला आहे. तुमच्या स्पष्ट संमतीशिवाय आम्ही तुमची माहिती सामायिक करत नाही.',
      'gu':
          'અમે તમારી વ્યક્તિગત અને તબીબી માહિતીનું રક્ષણ કરવા પ્રતિબદ્ધ છીએ. સમગ્ર ડેટા એનક્રિપ્ટ કરાયેલ અને સુરક્ષિત રીતે સંગ્રહિત છે. તમારી સ્પષ્ટ સંમતિ વિના અમે તમારી માહિતી શેર કરતા નથી.',
    },
    'termsPage.section5.title': {
      'en': '5. User Responsibilities',
      'hi': '5. उपयोगकर्ता की जिम्मेदारियाँ',
      'mr': '5. वापरकर्ता जबाबदाऱ्या',
      'gu': '5. વપરાશકર્તાની જવાબદારીઓ',
    },
    'termsPage.section5.body': {
      'en':
          'You are responsible for maintaining accurate medical information, keeping your login credentials secure, complying with applicable laws, and not sharing your account with others.',
      'hi':
          'आपकी जिम्मेदारी है कि आप अपनी चिकित्सा जानकारी सटीक रखें, अपने लॉगिन क्रेडेंशियल्स सुरक्षित रखें, लागू कानूनों का पालन करें और अपना खाता दूसरों के साथ साझा न करें।',
      'mr':
          'तुमची जबाबदारी आहे की तुमची वैद्यकीय माहिती अचूक ठेवा, तुमची लॉगिन क्रेडेंशियल्स सुरक्षित ठेवा, लागू कायद्यांचे पालन करा आणि तुमचे खाते इतरांसह सामायिक करू नका.',
      'gu':
          'તમારી જવાબદારી છે કે તમે તમારી તબીબી માહિતી સચોટ રાખો, તમારા લોગિન ક્રેડેન્શિયલ્સ સુરક્ષિત રાખો, લાગુ કાયદાનું પાલન કરો અને તમારું ખાતું અન્ય સાથે શૅર ન કરો.',
    },
    'termsPage.section6.title': {
      'en': '6. Prohibited Uses',
      'hi': '6. निषिद्ध उपयोग',
      'mr': '6. प्रतिबंधित वापर',
      'gu': '6. પ્રતિબંધિત ઉપયોગ',
    },
    'termsPage.section6.body': {
      'en':
          'You may not use our application for unlawful purposes, to violate regulations, infringe intellectual property rights, or harass and discriminate against others.',
      'hi':
          'आप हमारे ऐप का उपयोग किसी अवैध उद्देश्य के लिए, नियमों का उल्लंघन करने के लिए, बौद्धिक संपदा अधिकारों का उल्लंघन करने के लिए, या दूसरों को परेशान और भेदभाव करने के लिए नहीं कर सकते।',
      'mr':
          'तुम्ही आमचा अनुप्रयोग बेकायदेशीर उद्देशांसाठी, नियमांचे उल्लंघन करण्यासाठी, बौद्धिक मालमत्ता हक्कांचे उल्लंघन करण्यासाठी किंवा इतरांना त्रास देण्यासाठी आणि भेदभाव करण्यासाठी वापरू शकत नाही.',
      'gu':
          'તમે અમારા ઍપનો ઉપયોગ ગેરકાયદેસર હેતુઓ માટે, નિયમોનું ઉલ્લંઘન કરવા માટે, બૌદ્ધિક સંપત્તિ અધિકારોનું ઉલ્લંઘન કરવા માટે અથવા અન્યને હેરાન અને ભેદભાવ કરવા માટે કરી શકતા નથી.',
    },
    'termsPage.section7.title': {
      'en': '7. Content Accuracy',
      'hi': '7. सामग्री की सटीकता',
      'mr': '7. सामग्रीची अचूकता',
      'gu': '7. સામગ્રીની ચોકસાઈ',
    },
    'termsPage.section7.body': {
      'en':
          'We strive to provide accurate and up-to-date information, but we make no warranties about the completeness, reliability, or accuracy of the information provided.',
      'hi':
          'हम सटीक और अद्यतित जानकारी प्रदान करने का प्रयास करते हैं, लेकिन हम प्रदान की गई जानकारी की पूर्णता, विश्वसनीयता या सटीकता के बारे में कोई वारंटी नहीं देते।',
      'mr':
          'आम्ही अचूक आणि अद्ययावत माहिती प्रदान करण्याचा प्रयत्न करतो, परंतु दिलेल्या माहितीसंबंधी पूर्णता, विश्वसनीयता किंवा अचूकतेची हमी देत नाही.',
      'gu':
          'અમે સચોટ અને અદ્યતન માહિતી પ્રદાન કરવાનો પ્રયત્ન કરીએ છીએ, પરંતુ પ્રદાન કરેલી માહિતીની પૂર્ણતા, વિશ્વસનીયતા અથવા ચોકસાઈ અંગે કોઈ વોરંટી આપતા નથી.',
    },
    'termsPage.section8.title': {
      'en': '8. Limitation of Liability',
      'hi': '8. दायित्व की सीमा',
      'mr': '8. दायित्वाची मर्यादा',
      'gu': '8. જવાબદારીની મર્યાદા',
    },
    'termsPage.section8.body': {
      'en':
          'In no event shall Medical Vault or its affiliates be liable for any indirect, incidental, consequential, or special damages arising out of or related to your use of the application.',
      'hi':
          'किसी भी स्थिति में मेडिकल वॉल्ट या इसके सहयोगी आपके ऐप उपयोग से उत्पन्न किसी भी अप्रत्यक्ष, आकस्मिक, परिणामी या विशेष क्षति के लिए ज़िम्मेदार नहीं होंगे।',
      'mr':
          'कुठल्याही परिस्थितीत मेडिकल व्हॉल्ट किंवा त्याचे सहयोगी अनुप्रयोगाच्या वापरामुळे उद्भवलेल्या अप्रत्यक्ष, आकस्मिक, परिणामी किंवा विशेष नुकसानीसाठी जबाबदार राहणार नाहीत.',
      'gu':
          'કોઈપણ પરિસ્થિતિમાં મેડિકલ વોલ્ટ અથવા તેના સહયોગીઓ ઍપ્લિકેશનના તમારા ઉપયોગને કારણે ઉત્પન્ન થતી પરોક્ષ, આકસ્મિક, અનુગામી અથવા વિશેષ નુકસાન માટે જવાબદાર રહેશે નહીં.',
    },
    'termsPage.section9.title': {
      'en': '9. Termination',
      'hi': '9. समाप्ति',
      'mr': '9. समाप्ती',
      'gu': '9. સમાપ્તી',
    },
    'termsPage.section9.body': {
      'en':
          'We may terminate or suspend your account and access to the application immediately, without notice, for any reason, including breach of these Terms.',
      'hi':
          'हम किसी भी कारण से, जिसमें इन नियमों का उल्लंघन शामिल है, बिना सूचना के आपका खाता और ऐप का उपयोग तुरंत समाप्त या निलंबित कर सकते हैं।',
      'mr':
          'या नियमांचे उल्लंघन यासह कोणत्याही कारणास्तव आम्ही पूर्वसूचना न देता तुमचे खाते आणि अनुप्रयोगाचा प्रवेश त्वरित समाप्त किंवा निलंबित करू शकतो.',
      'gu':
          'અમે કોઈપણ કારણસર, જેમાં આ શરતોનો ભંગ પણ સમાવેશ થાય છે, તમારી અરજ અને ઍપ્લિકેશન સુધીની ઍક્સેસને નોટિસ વિના તાત્કાલિક રદ્દ અથવા સસ્પેન્ડ કરી શકીએ છીએ.',
    },
    'termsPage.section10.title': {
      'en': '10. Changes to Terms',
      'hi': '10. नियमों में बदलाव',
      'mr': '10. अटींमध्ये बदल',
      'gu': '10. શરતોમાં ફેરફાર',
    },
    'termsPage.section10.body': {
      'en':
          'We reserve the right to modify these Terms at any time. Your continued use of the application following any changes constitutes acceptance of the new Terms.',
      'hi':
          'हम इन नियमों में किसी भी समय संशोधन करने का अधिकार रखते हैं। किसी भी बदलाव के बाद ऐप का आपका निरंतर उपयोग नए नियमों की स्वीकृति दर्शाता है।',
      'mr':
          'आम्ही कोणत्याही वेळी या अटींमध्ये बदल करण्याचा अधिकार राखून ठेवतो. कोणत्याही बदलांनंतर अनुप्रयोगाचा तुमचा सतत वापर नवीन अटींच्या स्वीकृतीचे द्योतक आहे.',
      'gu':
          'અમે કોઈપણ સમયે આ શરતોમાં ફેરફાર કરવાનો અધિકાર રાખીએ છીએ. કોઈપણ ફેરફાર પછી ઍપ્લિકેશનનો તમારો સતત ઉપયોગ નવી શરતોની સ્વીકાર્યતા દર્શાવે છે.',
    },
    'termsPage.section11.title': {
      'en': '11. Contact Information',
      'hi': '11. संपर्क जानकारी',
      'mr': '11. संपर्क माहिती',
      'gu': '11. સંપર્ક માહિતી',
    },
    'termsPage.section11.body': {
      'en':
          'If you have any questions about these Terms and Conditions, please contact us at support@medicalvault.com or +1 (555) 123-4567.',
      'hi':
          'यदि आपको इन नियमों और शर्तों के बारे में कोई प्रश्न हैं, तो कृपया support@medicalvault.com या +1 (555) 123-4567 पर हमसे संपर्क करें।',
      'mr':
          'या नियम आणि अटींबद्दल काही प्रश्न असल्यास कृपया support@medicalvault.com किंवा +1 (555) 123-4567 वर आमच्याशी संपर्क साधा.',
      'gu':
          'જો તમને આ નિયમો અને શરતો વિશે કોઈ પ્રશ્ન હોય તો કૃપા કરીને support@medicalvault.com અથવા +1 (555) 123-4567 પર અમારો સંપર્ક કરો.',
    },
    'termsOfService.title': {
      'en': 'Terms of Service',
      'hi': 'सेवा की शर्तें',
      'mr': 'सेवेच्या अटी',
      'gu': 'સેવાની શરતો',
    },
    'termsOfService.accept': {
      'en': 'Accept',
      'hi': 'स्वीकारें',
      'mr': 'स्वीकारा',
      'gu': 'સ્વીકારો',
    },
    'termsOfService.intro': {
      'en':
          'Welcome to our Health Vault App! By using our services, you agree to the following Terms and Conditions. Please read them carefully.',
      'hi':
          'हमारे हेल्थ वॉल्ट ऐप में आपका स्वागत है! हमारी सेवाओं का उपयोग करके, आप निम्नलिखित नियमों और शर्तों से सहमत होते हैं। कृपया उन्हें ध्यान से पढ़ें।',
      'mr':
          'आमच्या हेल्थ व्हॉल्ट ऍपमध्ये तुमचे स्वागत आहे! आमच्या सेवांचा वापर करून, तुम्ही खालील नियम आणि अटींना सहमती देता. कृपया ते काळजीपूर्वक वाचा.',
      'gu':
          'અમારા હેલ્થ વોલ્ટ ઍપમાં તમારું સ્વાગત છે! અમારી સેવાઓનો ઉપયોગ કરીને, તમે નીચેની શરતો અને નિયમો સાથે સંમત થાઓ છો. કૃપા કરીને તેમને ધ્યાનથી વાંચો.',
    },
    'termsOfService.section1': {
      'en':
          '1. Acceptance of Terms\nBy accessing or using our app, you acknowledge that you have read, understood, and agree to be bound by these terms. If you do not agree, please do not use our services.',
      'hi':
          '1. नियमों का स्वीकार\nहमारे ऐप का उपयोग करके, आप स्वीकार करते हैं कि आपने इन नियमों को पढ़ा, समझा और उनसे बंधे रहने के लिए सहमत हैं। यदि आप सहमत नहीं हैं, तो कृपया हमारी सेवाओं का उपयोग न करें।',
      'mr':
          '1. अटींची स्वीकृती\nआमचा अनुप्रयोग वापरून, तुम्ही या अटी वाचल्या, समजल्या आणि त्यांचे पालन करण्यास सहमत आहात हे मान्य करता. तुम्ही सहमत नसल्यास, कृपया आमच्या सेवांचा वापर करू नका.',
      'gu':
          '1. શરતોનો સ્વીકાર\nઅમારું ઍપ વાપરીને, તમે સ્વીકારો છો કે તમે આ શરતો વાંચી અને સમજી છે અને તેમનું પાલન કરવા સંમત છો. જો તમે સંમત ન હોવ, તો કૃપા કરીને અમારી સેવાઓનો ઉપયોગ ન કરો.',
    },
    'termsOfService.section2': {
      'en':
          '2. Description of Services\nOur app provides a platform for managing your healthcare, including scheduling appointments, accessing medical records, and communicating with healthcare providers.',
      'hi':
          '2. सेवाओं का विवरण\nहमारा ऐप आपके स्वास्थ्य प्रबंधन के लिए एक मंच प्रदान करता है, जिसमें अपॉइंटमेंट शेड्यूल करना, चिकित्सा रिकॉर्ड तक पहुंचना और स्वास्थ्य प्रदाताओं के साथ संचार करना शामिल है।',
      'mr':
          '2. सेवांचे वर्णन\nआमचे ऍप तुमच्या आरोग्य व्यवस्थापनासाठी एक व्यासपीठ प्रदान करते, ज्यामध्ये भेटी नियोजित करणे, वैद्यकीय नोंदींमध्ये प्रवेश करणे आणि आरोग्य सेवा प्रदात्यांशी संवाद साधणे यांचा समावेश आहे.',
      'gu':
          '2. સેવાઓનું વર્ણન\nઅમારું ઍપ તમારા હેલ્થકેર મેનેજમેન્ટ માટે પ્લેટફોર્મ પ્રદાન કરે છે, જેમાં અપોઇન્ટમેન્ટનું શેડ્યૂલિંગ, તબીબી રેકોર્ડ્સ ઍક્સેસ કરવી અને હેલ્થકેર પ્રદાતાઓ સાથે સંચાર કરવો શામેલ છે.',
    },
    'termsOfService.section3': {
      'en':
          '3. User Accounts\nYou are responsible for maintaining the confidentiality of your account information and for all activities that occur under your account. Notify us immediately of any unauthorized use.',
      'hi':
          '3. उपयोगकर्ता खाते\nआप अपने खाते की जानकारी की गोपनीयता बनाए रखने और आपके खाते के तहत होने वाली सभी गतिविधियों के लिए ज़िम्मेदार हैं। किसी भी अनधिकृत उपयोग की तुरंत सूचना दें।',
      'mr':
          '3. वापरकर्ता खाती\nतुमच्या खात्याची माहिती गोपनीय राखणे आणि तुमच्या खात्याखाली घडणाऱ्या सर्व क्रियाकलापांसाठी तुम्ही जबाबदार आहात. कोणत्याही अनधिकृत वापराबद्दल आम्हाला त्वरित कळवा.',
      'gu':
          '3. વપરાશકર્તા ખાતાઓ\nતમારા ખાતાની માહિતીની ગોપનીયતા જાળવવા અને તમારા ખાતા હેઠળ થતી તમામ પ્રવૃત્તિઓ માટે તમે જવાબદાર છો. કોઈપણ અનધિકૃત ઉપયોગની તાત્કાલિક જાણ કરો.',
    },
    'termsOfService.section4': {
      'en':
          '4. Privacy Policy\nYour privacy is important to us. Our Privacy Policy explains how we collect, use, and protect your personal information.',
      'hi':
          '4. गोपनीयता नीति\nआपकी गोपनीयता हमारे लिए महत्वपूर्ण है। हमारी गोपनीयता नीति बताती है कि हम आपकी व्यक्तिगत जानकारी कैसे एकत्र करते हैं, उपयोग करते हैं और सुरक्षित रखते हैं।',
      'mr':
          '4. गोपनीयता धोरण\nतुमची गोपनीयता आमच्यासाठी महत्त्वाची आहे. आमचे गोपनीयता धोरण आम्ही तुमची वैयक्तिक माहिती कशी गोळा करतो, वापरतो आणि सुरक्षित ठेवतो हे स्पष्ट करते.',
      'gu':
          '4. ગોપનીયતા નીતિ\nતમારી ગોપનીયતા અમારે માટે મહત્વપૂર્ણ છે. અમારી ગોપનીયતા નીતિ સમજાવે છે કે અમે તમારી વ્યક્તિગત માહિતી કેવી રીતે એકત્ર કરીએ છીએ, તેનો ઉપયોગ કરીએ છીએ અને સુરક્ષિત કરીએ છીએ.',
    },
    'termsOfService.section5': {
      'en':
          '5. Disclaimer of Warranties\nOur app is provided "as is" without any warranties, express or implied. We do not guarantee the accuracy or reliability of the information provided.',
      'hi':
          '5. वारंटी का अस्वीकरण\nहमारा ऐप "जैसा है" के आधार पर प्रदान किया जाता है, किसी भी तरह की व्यक्त या निहित वारंटी के बिना। हम प्रदान की गई जानकारी की सटीकता या विश्वसनीयता की गारंटी नहीं देते।',
      'mr':
          '5. हमीचा नकार\nआमचा ऍप "जे आहे ते" या तत्त्वावर प्रदान केला जातो, कोणत्याही व्यक्त किंवा सूचित हमीशिवाय. आम्ही दिलेल्या माहितीसंबंधी अचूकतेची किंवा विश्वसनीयतेची हमी देत नाही.',
      'gu':
          '5. વોરંટીનો નિષ્કર્ષ\nઅમારું ઍપ "જે રીતે છે" તે રીતે પ્રદાન કરવામાં આવે છે, કોઈપણ સ્પષ્ટ અથવા નિહિત વોરંટી વિના. અમે પ્રદાન કરેલી માહિતીની ચોકસાઈ અથવા વિશ્વસનીયતાની ખાતરી આપતા નથી.',
    },
    'termsOfService.section6': {
      'en':
          '6. Limitation of Liability\nWe are not liable for any direct, indirect, incidental, consequential, or punitive damages arising from your use of our app.',
      'hi':
          '6. दायित्व की सीमा\nहमारे ऐप के उपयोग से उत्पन्न किसी भी प्रत्यक्ष, अप्रत्यक्ष, आकस्मिक, परिणामी या दंडात्मक क्षति के लिए हम ज़िम्मेदार नहीं हैं।',
      'mr':
          '6. दायित्वाची मर्यादा\nआमच्या अनुप्रयोगाच्या वापरामुळे उद्भवलेल्या कोणत्याही थेट, अप्रत्यक्ष, आकस्मिक, परिणामी किंवा दंडात्मक नुकसानीसाठी आम्ही जबाबदार नाही.',
      'gu':
          '6. જવાબદારીની મર્યાદા\nઅમારા ઍપના તમારા ઉપયોગથી ઉત્પન્ન થતી કોઈપણ સીધી, આકસ્મિક, અનુગામી અથવા દંડાત્મક નુકસાન માટે અમે જવાબદાર નથી.',
    },
    'termsOfService.section7': {
      'en':
          '7. Modifications to Terms\nWe reserve the right to modify these terms at any time. Continued use of the app after changes means you accept the updated terms.',
      'hi':
          '7. नियमों में संशोधन\nहम किसी भी समय इन नियमों में संशोधन करने का अधिकार रखते हैं। परिवर्तनों के बाद ऐप का निरंतर उपयोग करने का अर्थ है कि आप अपडेटेड नियमों को स्वीकार करते हैं।',
      'mr':
          '7. अटींमध्ये बदल\nआम्ही कोणत्याही वेळी या अटींमध्ये बदल करण्याचा अधिकार राखून ठेवतो. बदलांनंतर ऍपचा सतत वापर करणे म्हणजे तुम्ही अद्यतनित अटी स्वीकारता.',
      'gu':
          '7. શરતોમાં ફેરફાર\nઅમે કોઈપણ સમયે આ શરતોમાં ફેરફાર કરવાનો અધિકાર રાખીએ છીએ. ફેરફાર પછી ઍપનો સતત ઉપયોગ કરવાનો મતલબ છે કે તમે અપડેટ કરેલી શરતો સ્વીકારો છો.',
    },
    'termsOfService.section8': {
      'en':
          '8. Governing Law\nThese terms are governed by the laws of the jurisdiction in which our company is registered.',
      'hi':
          '8. शासित कानून\nये नियम उस अधिकार क्षेत्र के कानूनों द्वारा नियंत्रित होते हैं जिसमें हमारी कंपनी पंजीकृत है।',
      'mr':
          '8. लागू कायदा\nया अटी आमची कंपनी नोंदणीकृत असलेल्या अधिकारक्षेत्रातील कायद्यांद्वारे नियंत्रित केल्या जातात.',
      'gu':
          '8. ગવર્નિંગ કાયદો\nઆ શરતો અમારા કંપની નોંધાયેલ ક્ષેત્રક્ષેત્રના કાયદાઓ દ્વારા નિયંત્રિત થાય છે.',
    },
    'faq.title': {
      'en': 'FAQs',
      'hi': 'सामान्य प्रश्न',
      'mr': 'नेहमी विचारले जाणारे प्रश्न',
      'gu': 'વારંવાર પૂછાતા પ્રશ્નો',
    },
    'faq.item1.question': {
      'en': 'How do I upload my medical documents?',
      'hi': 'मैं अपने चिकित्सा दस्तावेज़ कैसे अपलोड करूं?',
      'mr': 'मी माझे वैद्यकीय दस्तऐवज कसे अपलोड करू?',
      'gu': 'હું મારી તબીબી દસ્તાવેજો કેવી રીતે અપલોડ કરું?',
    },
    'faq.item1.answer': {
      'en':
          'Go to the Documents section, tap Upload, and select the files from your device. Ensure they are within the supported format and size limits.',
      'hi':
          'दस्तावेज़ अनुभाग में जाएं, "अपलोड" टैप करें और अपने डिवाइस से फ़ाइलें चुनें। सुनिश्चित करें कि वे समर्थित फ़ॉर्मेट और आकार सीमा में हैं।',
      'mr':
          'दस्तऐवज विभागात जा, "अपलोड" टॅप करा आणि तुमच्या डिव्हाइसवरून फाइल निवडा. त्या समर्थित स्वरूप आणि आकार मर्यादेत आहेत याची खात्री करा.',
      'gu':
          'દસ્તાવેજ વિભાગમાં જાઓ, "અપલોડ" ટેપ કરો અને તમારા ઉપકરણમાંથી ફાઈલો પસંદ કરો. ખાતરી કરો કે તેઓ સમર્થિત ફોર્મેટ અને કદ મર્યાદામાં છે.',
    },
    'faq.item2.question': {
      'en': 'What file formats are supported?',
      'hi': 'कौन से फ़ाइल फ़ॉर्मेट समर्थित हैं?',
      'mr': 'कोणते फाईल स्वरूप समर्थित आहेत?',
      'gu': 'કયા ફાઇલ ફોર્મેટ્સ સમર્થિત છે?',
    },
    'faq.item2.answer': {
      'en': 'We support PDF, JPEG, PNG, and DOCX formats.',
      'hi': 'हम PDF, JPEG, PNG और DOCX फ़ॉर्मेट का समर्थन करते हैं।',
      'mr': 'आम्ही PDF, JPEG, PNG आणि DOCX स्वरूपाचे समर्थन करतो.',
      'gu': 'અમે PDF, JPEG, PNG અને DOCX ફોર્મેટ્સને સમર્થન આપીએ છીએ.',
    },
    'faq.item3.question': {
      'en': 'Is there a size limit for uploads?',
      'hi': 'क्या अपलोड के लिए आकार सीमा है?',
      'mr': 'अपलोडसाठी आकार मर्यादा आहे का?',
      'gu': 'અપલોડ માટે કદ મર્યાદા છે?',
    },
    'faq.item3.answer': {
      'en': 'Yes, each file must be under 10 MB.',
      'hi': 'हाँ, प्रत्येक फ़ाइल 10 MB से कम होनी चाहिए।',
      'mr': 'होय, प्रत्येक फाईल 10 MB पेक्षा कमी असावी.',
      'gu': 'હા, દરેક ફાઇલ 10 MB કરતાં ઓછી હોવી જોઈએ.',
    },
    'faq.item4.question': {
      'en': 'Can I upload multiple documents at once?',
      'hi': 'क्या मैं एक ही बार में कई दस्तावेज़ अपलोड कर सकता हूँ?',
      'mr': 'मी एकाच वेळी अनेक दस्तऐवज अपलोड करू शकतो का?',
      'gu': 'શું હું એક સાથે અનેક દસ્તાવેજો અપલોડ કરી શકું?',
    },
    'faq.item4.answer': {
      'en': 'Yes, you can select multiple files in one upload session.',
      'hi': 'हाँ, आप एक ही अपलोड सत्र में कई फ़ाइलें चुन सकते हैं।',
      'mr': 'होय, तुम्ही एकाच अपलोड सत्रात एकापेक्षा जास्त फाइल निवडू शकता.',
      'gu': 'હા, તમે એક જ અપલોડ સત્રમાં અનેક ફાઇલો પસંદ કરી શકો છો.',
    },
    'faq.item5.question': {
      'en': 'How do I know if my documents were uploaded successfully?',
      'hi':
          'मुझे कैसे पता चलेगा कि मेरे दस्तावेज़ सफलतापूर्वक अपलोड हो गए हैं?',
      'mr':
          'माझे दस्तऐवज यशस्वीरित्या अपलोड झाले आहेत की नाही हे मला कसे कळेल?',
      'gu':
          'મને કેવી રીતે ખબર પડશે કે મારા દસ્તાવેજો સફળતાપૂર્વક અપલોડ થયા છે?',
    },
    'faq.item5.answer': {
      'en':
          'You will receive a confirmation notification, and the documents will appear in your Documents list.',
      'hi':
          'आपको एक पुष्टि सूचना प्राप्त होगी और दस्तावेज़ आपकी दस्तावेज़ सूची में दिखाई देंगे।',
      'mr':
          'तुम्हाला पुष्टी सूचना मिळेल आणि दस्तऐवज तुमच्या दस्तऐवज सूचीमध्ये दिसतील.',
      'gu':
          'તમને એક પુષ્ટિ સૂચના મળશે અને દસ્તાવેજો તમારી દસ્તાવેજોની યાદીમાં દેખાશે.',
    },
    'contactSupport.title': {
      'en': 'Contact Support',
      'hi': 'सहायता से संपर्क करें',
      'mr': 'सपोर्टशी संपर्क करा',
      'gu': 'સપોર્ટનો સંપર્ક કરો',
    },
    'contactSupport.emailTitle': {
      'en': 'Email Support',
      'hi': 'ईमेल सहायता',
      'mr': 'ईमेल समर्थन',
      'gu': 'ઇમેઇલ સપોર્ટ',
    },
    'contactSupport.emailValue': {
      'en': 'medicalvault@aially.in',
      'hi': 'medicalvault@aially.in',
      'mr': 'medicalvault@aially.in',
      'gu': 'medicalvault@aially.in',
    },
    'contactSupport.phoneTitle': {
      'en': 'Call Support',
      'hi': 'कॉल सहायता',
      'mr': 'कॉल समर्थन',
      'gu': 'કૉલ સપોર્ટ',
    },
    'contactSupport.phoneValue': {
      'en': '+91 98765 43210',
      'hi': '+91 98765 43210',
      'mr': '+91 98765 43210',
      'gu': '+91 98765 43210',
    },
    'privacy.update1.version': {
      'en': '1.1',
      'hi': '1.1',
      'mr': '1.1',
      'gu': '1.1',
    },
    'privacy.update1.date': {
      'en': '2024-01-15',
      'hi': '2024-01-15',
      'mr': '2024-01-15',
      'gu': '2024-01-15',
    },
    'privacy.update1.change1': {
      'en': 'Added biometric authentication support',
      'hi': 'बायोमेट्रिक प्रमाणीकरण समर्थन जोड़ा गया',
      'mr': 'बायोमेट्रिक प्रमाणीकरण समर्थन जोडले',
      'gu': 'બાયોમેટ્રિક ઓથેન્ટિકેશન સપોર્ટ ઉમેરાયો',
    },
    'privacy.update1.change2': {
      'en': 'Enhanced data encryption protocols',
      'hi': 'डेटा एन्क्रिप्शन प्रोटोकॉल को बेहतर बनाया गया',
      'mr': 'डेटा एन्क्रिप्शन प्रोटोकॉल सुधारले',
      'gu': 'ડેટા એનક્રિપ્શન પ્રોટોકોલ સુધાર્યા',
    },
    'privacy.update1.change3': {
      'en': 'Updated third-party data sharing policies',
      'hi': 'तृतीय-पक्ष डेटा साझा करने की नीतियाँ अपडेट की गईं',
      'mr': 'तृतीय-पक्ष डेटा शेअरिंग धोरणे अद्यतनित केली',
      'gu': 'તૃતીય પક્ષ ડેટા શેરિંગ નીતીઓ અપડેટ કરી',
    },
    'privacy.update2.version': {
      'en': '1.0',
      'hi': '1.0',
      'mr': '1.0',
      'gu': '1.0',
    },
    'privacy.update2.date': {
      'en': '2024-01-01',
      'hi': '2024-01-01',
      'mr': '2024-01-01',
      'gu': '2024-01-01',
    },
    'privacy.update2.change1': {
      'en': 'Initial privacy policy implementation',
      'hi': 'प्रारंभिक गोपनीयता नीति लागू की गई',
      'mr': 'प्रारंभिक गोपनीयता धोरण अंमलात आणले',
      'gu': 'પ્રારંભિક ગોપનીયતા નીતિ અમલમાં મૂકી',
    },
    'privacy.update2.change2': {
      'en': 'Basic data collection and usage policies',
      'hi': 'मूलभूत डेटा संग्रहण और उपयोग नीतियाँ',
      'mr': 'मूलभूत डेटा संकलन आणि वापर धोरणे',
      'gu': 'મૂળભૂત ડેટા સંગ્રહ અને ઉપયોગ નીતિઓ',
    },
    'privacy.update2.change3': {
      'en': 'User consent mechanisms',
      'hi': 'उपयोगकर्ता सहमति तंत्र',
      'mr': 'वापरकर्ता संमती यंत्रणा',
      'gu': 'વપરાશકર્તા સંમતિ મિકેનિઝમ',
    },
    'privacy.update.versionLabel': {
      'en': 'Version {version}',
      'hi': 'संस्करण {version}',
      'mr': 'आवृत्ती {version}',
      'gu': 'આવૃત્તિ {version}',
    },
    'changePassword.title': {
      'en': 'Change Password',
      'hi': 'पासवर्ड बदलें',
      'mr': 'पासवर्ड बदला',
      'gu': 'પાસવર્ડ બદલો',
    },
    'changePassword.heading': {
      'en': 'Change your password',
      'hi': 'अपना पासवर्ड बदलें',
      'mr': 'तुमचा पासवर्ड बदला',
      'gu': 'તમારો પાસવર્ડ બદલો',
    },
    'changePassword.subheading': {
      'en': 'Enter your new password and confirm.',
      'hi': 'अपना नया पासवर्ड दर्ज करें और पुष्टि करें।',
      'mr': 'नवीन पासवर्ड टाका आणि पुष्टी करा.',
      'gu': 'તમારો નવો પાસવર્ડ દાખલ કરો અને પુષ્ટિ કરો.',
    },
    'changePassword.current': {
      'en': 'Current Password',
      'hi': 'वर्तमान पासवर्ड',
      'mr': 'सध्याचा पासवर्ड',
      'gu': 'હાલનો પાસવર્ડ',
    },
    'changePassword.new': {
      'en': 'New Password',
      'hi': 'नया पासवर्ड',
      'mr': 'नवीन पासवर्ड',
      'gu': 'નવો પાસવર્ડ',
    },
    'changePassword.confirm': {
      'en': 'Confirm New Password',
      'hi': 'नए पासवर्ड की पुष्टि करें',
      'mr': 'नवीन पासवर्डची पुष्टी करा',
      'gu': 'નવો પાસવર્ડ ખાતરી કરો',
    },
    'changePassword.hint': {
      'en': 'Enter {field}',
      'hi': '{field} दर्ज करें',
      'mr': '{field} प्रविष्ट करा',
      'gu': '{field} દાખલ કરો',
    },
    'changePassword.updateButton': {
      'en': 'Update Password',
      'hi': 'पासवर्ड अपडेट करें',
      'mr': 'पासवर्ड अद्यतन करा',
      'gu': 'પાસવર્ડ અપડેટ કરો',
    },
    'changePassword.error.missingFields': {
      'en': 'Please fill in all fields',
      'hi': 'कृपया सभी फ़ील्ड भरें',
      'mr': 'कृपया सर्व फील्ड भरा',
      'gu': 'કૃપા કરીને બધા ક્ષેત્ર ભરો',
    },
    'changePassword.error.mismatch': {
      'en': 'New passwords do not match',
      'hi': 'नए पासवर्ड मेल नहीं खाते',
      'mr': 'नवीन पासवर्ड जुळत नाहीत',
      'gu': 'નવા પાસવર્ડ મેળ ખાતા નથી',
    },
    'changePassword.error.minLength': {
      'en': 'Password must be at least 6 characters long',
      'hi': 'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए',
      'mr': 'पासवर्ड किमान 6 अक्षरे असावा',
      'gu': 'પાસવર્ડ ઓછામાં ઓછા 6 અક્ષરોનો હોવો જોઈએ',
    },
    'changePassword.successFallback': {
      'en': 'Password updated successfully',
      'hi': 'पासवर्ड सफलतापूर्वक अपडेट किया गया',
      'mr': 'पासवर्ड यशस्वीपणे अद्यतनित केला',
      'gu': 'પાસવર્ડ સફળતાપૂર્વક અપડેટ થયો',
    },
    'changePassword.failureFallback': {
      'en': 'Failed to update password',
      'hi': 'पासवर्ड अपडेट करने में विफल',
      'mr': 'पासवर्ड अद्यतन करण्यात अयशस्वी',
      'gu': 'પાસવર્ડ અપડેટ કરવામાં નિષ્ફળ',
    },
    'privacyPage.title': {
      'en': 'Privacy Policy',
      'hi': 'गोपनीयता नीति',
      'mr': 'गोपनीयता धोरण',
      'gu': 'ગોપનીયતા નીતિ',
    },
    'privacyPage.lastUpdated': {
      'en': 'Last updated: {date}',
      'hi': 'अंतिम अपडेट: {date}',
      'mr': 'शेवटचे अद्यतन: {date}',
      'gu': 'છેલ્લું અપડેટ: {date}',
    },
    'privacyPage.summary': {
      'en':
          'Your privacy is important to us. This Privacy Policy explains how we collect, use, and protect your information when you use Medical Vault.',
      'hi':
          'आपकी गोपनीयता हमारे लिए महत्वपूर्ण है। यह गोपनीयता नीति बताती है कि मेडिकल वॉल्ट का उपयोग करते समय हम आपकी जानकारी कैसे एकत्र करते हैं, उपयोग करते हैं और सुरक्षित रखते हैं।',
      'mr':
          'तुमची गोपनीयता आमच्यासाठी महत्त्वाची आहे. ही गोपनीयता धोरण तुम्ही मेडिकल व्हॉल्ट वापरताना आम्ही तुमची माहिती कशी गोळा करतो, वापरतो आणि सुरक्षित ठेवतो हे स्पष्ट करते.',
      'gu':
          'તમારી ગોપનીયતા અમારે માટે મહત્વપૂર્ણ છે. આ ગોપનીયતા નીતિ સમજાવે છે કે જ્યારે તમે મેડિકલ વોલ્ટનો ઉપયોગ કરો ત્યારે અમે તમારી માહિતી કેવી રીતે એકત્રિત, ઉપયોગ અને સુરક્ષિત કરીએ છીએ.',
    },
    'privacyPage.section1.title': {
      'en': '1. Information We Collect',
      'hi': '1. हम कौन सी जानकारी एकत्र करते हैं',
      'mr': '1. आम्ही कोणती माहिती गोळा करतो',
      'gu': '1. અમે કઈ માહિતી એકત્ર કરીએ છીએ',
    },
    'privacyPage.section1.body': {
      'en':
          'We collect information you provide directly to us, such as when you create an account, upload medical documents, or contact us for support. This may include:\n• Personal Information: Name, email address, phone number\n• Medical Information: Medical records, prescriptions, lab reports, insurance documents\n• Account Information: Username, password, profile information\n• Usage Information: How you interact with our application',
      'hi':
          'हम सीधे आपसे प्रदान की गई जानकारी एकत्र करते हैं, जैसे कि जब आप खाता बनाते हैं, चिकित्सा दस्तावेज अपलोड करते हैं, या सहायता के लिए हमसे संपर्क करते हैं। इसमें शामिल हो सकता है:\n• व्यक्तिगत जानकारी: नाम, ईमेल पता, फोन नंबर\n• चिकित्सा जानकारी: चिकित्सा रिकॉर्ड, प्रिस्क्रिप्शन, लैब रिपोर्ट, बीमा दस्तावेज\n• खाता जानकारी: उपयोगकर्ता नाम, पासवर्ड, प्रोफ़ाइल जानकारी\n• उपयोग जानकारी: आप हमारे ऐप के साथ कैसे इंटरैक्ट करते हैं',
      'mr':
          'आम्ही तुमच्याकडून थेट दिलेली माहिती गोळा करतो, जसे की तुम्ही खाते तयार करता, वैद्यकीय दस्तऐवज अपलोड करता किंवा सहाय्यासाठी आमच्याशी संपर्क साधता. यात समाविष्ट असू शकते:\n• वैयक्तिक माहिती: नाव, ईमेल पत्ता, फोन नंबर\n• वैद्यकीय माहिती: वैद्यकीय नोंदी, प्रिस्क्रिप्शन, प्रयोगशाळा अहवाल, विमा दस्तऐवज\n• खाते माहिती: वापरकर्तानाव, पासवर्ड, प्रोफाइल माहिती\n• वापर माहिती: तुम्ही आमच्या अनुप्रयोगाशी कसा संवाद करता',
      'gu':
          'અમે તમારી પાસેથી સીધી પ્રાપ્ત કરવામાં આવેલી માહિતી એકત્રિત કરીએ છીએ, જેમ કે જ્યારે તમે ખાતું બનાવો, તબીબી દસ્તાવેજો અપલોડ કરો અથવા સપોર્ટ માટે અમારો સંપર્ક કરો. તેમાં આનો સમાવેશ થઈ શકે છે:\n• વ્યક્તિગત માહિતી: નામ, ઇમેલ સરનામું, ફોન નંબર\n• તબીબી માહિતી: તબીબી રેકોર્ડ, પ્રિસ્ક્રિપ્શન, લૅબ રિપોર્ટ, વીમા દસ્તાવેજો\n• ખાતા માહિતી: વપરાશકર્તા નામ, પાસવર્ડ, પ્રોફાઇલ માહિતી\n• ઉપયોગ માહિતી: તમે અમારી ઍપ સાથે કેવી રીતે ઇન્ટરેક્ટ કરો છો',
    },
    'privacyPage.section2.title': {
      'en': '2. How We Use Your Information',
      'hi': '2. हम आपकी जानकारी का उपयोग कैसे करते हैं',
      'mr': '2. आम्ही तुमची माहिती कशी वापरतो',
      'gu': '2. અમે તમારી માહિતી કેવી રીતે ઉપયોગમાં લઈએ છીએ',
    },
    'privacyPage.section2.body': {
      'en':
          'We use the information we collect to:\n• Provide, maintain, and improve our services\n• Process transactions and send related information\n• Send technical notices, updates, security alerts, and support messages\n• Respond to your comments, questions, and provide customer service\n• Monitor and analyze trends, usage, and activities in connection with our services',
      'hi':
          'हम एकत्र की गई जानकारी का उपयोग करते हैं:\n• अपनी सेवाओं को प्रदान करने, बनाए रखने और सुधारने के लिए\n• लेन-देन को संसाधित करने और संबंधित जानकारी भेजने के लिए\n• तकनीकी नोटिस, अपडेट, सुरक्षा अलर्ट और सहायता संदेश भेजने के लिए\n• आपकी टिप्पणियों, प्रश्नों का जवाब देने और ग्राहक सेवा प्रदान करने के लिए\n• हमारी सेवाओं से संबंधित रुझानों, उपयोग और गतिविधियों की निगरानी और विश्लेषण करने के लिए',
      'mr':
          'आम्ही गोळा केलेली माहिती वापरतो:\n• आमच्या सेवा प्रदान करण्यासाठी, राखण्यासाठी आणि सुधारण्यासाठी\n• व्यवहार प्रक्रिया करण्यासाठी आणि संबंधित माहिती पाठवण्यासाठी\n• तांत्रिक सूचना, अद्यतने, सुरक्षा अलर्ट आणि सहाय्य संदेश पाठवण्यासाठी\n• तुमच्या टिप्पणी, प्रश्नांना प्रतिसाद देण्यासाठी आणि ग्राहक सेवा प्रदान करण्यासाठी\n• आमच्या सेवांशी संबंधित ट्रेंड, वापर आणि क्रियाकलापांचे निरीक्षण आणि विश्लेषण करण्यासाठी',
      'gu':
          'અમે એકત્રિત માહિતીનો ઉપયોગ કરીએ છીએ:\n• અમારી સેવાઓ પૂરી પાડવા, જાળવવા અને સુધારવા માટે\n• વ્યવહારોની પ્રક્રિયા કરવા અને સંબંધિત માહિતી મોકલવા માટે\n• ટેકનિકલ સૂચનાઓ, અપડેટ, સુરક્ષા ચેતવણીઓ અને સપોર્ટ સંદેશાઓ મોકલવા માટે\n• તમારી ટિપ્પણી, પ્રશ્નોનો જવાબ આપવા અને ગ્રાહક સેવા આપવા માટે\n• અમારી સેવાઓ સંબંધિત પ્રવૃત્તિઓ, વપરાશ અને પ્રવણતાઓનું નિરીક્ષણ અને વિશ્લેષણ કરવા માટે',
    },
    'privacyPage.section3.title': {
      'en': '3. Information Sharing and Disclosure',
      'hi': '3. जानकारी साझा करना और प्रकटीकरण',
      'mr': '3. माहिती शेअर करणे आणि प्रकटीकरण',
      'gu': '3. માહિતી વહેંચવી અને ખુલાસો',
    },
    'privacyPage.section3.body': {
      'en':
          'We do not sell, trade, or otherwise transfer your personal information to third parties without your consent, except in the following circumstances:\n• With your explicit consent\n• To comply with legal obligations\n• To protect our rights, privacy, safety, or property\n• In connection with a merger, acquisition, or sale of assets\n• With healthcare providers when you authorize sharing',
      'hi':
          'हम आपकी सहमति के बिना आपकी व्यक्तिगत जानकारी को तीसरे पक्ष के साथ नहीं बेचते, व्यापार नहीं करते या स्थानांतरित नहीं करते, सिवाय निम्नलिखित परिस्थितियों में:\n• आपकी स्पष्ट सहमति के साथ\n• कानूनी दायित्वों का पालन करने के लिए\n• हमारे अधिकारों, गोपनीयता, सुरक्षा या संपत्ति की रक्षा करने के लिए\n• विलय, अधिग्रहण या संपत्ति की बिक्री से संबंधित\n• जब आप साझा करने की अनुमति देते हैं तो स्वास्थ्य सेवा प्रदाताओं के साथ',
      'mr':
          'तुमच्या संमतीशिवाय आम्ही तुमची वैयक्तिक माहिती तृतीय पक्षांना विकत नाही, व्यापार करीत नाही किंवा हस्तांतरित करीत नाही, खालील परिस्थिती वगळता:\n• तुमच्या स्पष्ट संमतीने\n• कायदेशीर बंधनांचे पालन करण्यासाठी\n• आमचे हक्क, गोपनीयता, सुरक्षा किंवा मालमत्ता संरक्षित करण्यासाठी\n• विलीनीकरण, अधिग्रहण किंवा मालमत्ता विक्रीच्या संदर्भात\n• जेव्हा तुम्ही सामायिकरण अधिकृत करता तेव्हा आरोग्य सेवा प्रदात्यांसोबत',
      'gu':
          'તમારી સંમતિ વિના અમે તમારી વ્યક્તિગત માહિતી તૃતીય પક્ષને વેચતા, વેપાર કરતા અથવા ટ્રાન્સફર કરતા નથી, સિવાય નીચેની પરિસ્થિતિઓમાં:\n• તમારી સ્પષ્ટ સંમતિ સાથે\n• કાનૂની બાંહેધરીઓનું પાલન કરવા માટે\n• અમારા હક્ક, ગોપનીયતા, સુરક્ષા અથવા સંપત્તિનું રક્ષણ કરવા માટે\n• મર્જર, ગૌણ વેચાણ અથવા સંપત્તિ વેચાણ સંદર્ભે\n• જ્યારે તમે શેર કરવાની મંજૂરી આપો ત્યારે હેલ્થકેર પ્રદાતાઓ સાથે',
    },
    'privacyPage.section4.title': {
      'en': '4. Data Security',
      'hi': '4. डेटा सुरक्षा',
      'mr': '4. डेटा सुरक्षा',
      'gu': '4. ડેટા સુરક્ષા',
    },
    'privacyPage.section4.body': {
      'en':
          'We implement appropriate security measures to protect your personal and medical information:\n• Encryption of data in transit and at rest\n• Secure authentication and access controls\n• Regular security audits and updates\n• Limited access to personal information on a need-to-know basis\n• Secure data centers with physical security measures',
      'hi':
          'हम आपकी व्यक्तिगत और चिकित्सा जानकारी की सुरक्षा के लिए उपयुक्त सुरक्षा उपाय लागू करते हैं:\n• डेटा को संचार और स्थिर अवस्था में एन्क्रिप्ट करना\n• सुरक्षित प्रमाणीकरण और एक्सेस नियंत्रण\n• नियमित सुरक्षा ऑडिट और अपडेट\n• आवश्यकता-के-आधार पर व्यक्तिगत जानकारी तक सीमित पहुंच\n• भौतिक सुरक्षा उपायों के साथ सुरक्षित डेटा केंद्र',
      'mr':
          'आम्ही तुमची वैयक्तिक आणि वैद्यकीय माहिती संरक्षित करण्यासाठी योग्य सुरक्षा उपायांची अंमलबजावणी करतो:\n• प्रवास आणि विश्रांतीतील डेटाचे एन्क्रिप्शन\n• सुरक्षित प्रमाणीकरण आणि प्रवेश नियंत्रण\n• नियमित सुरक्षा ऑडिट आणि अद्यतने\n• आवश्यकतेनुसार वैयक्तिक माहितीचा मर्यादित प्रवेश\n• भौतिक सुरक्षा उपायांसह सुरक्षित डेटा केंद्र',
      'gu':
          'અમે તમારી વ્યક્તિગત અને તબીબી માહિતીનું રક્ષણ કરવા માટે યોગ્ય સુરક્ષા પગલાં અમલમાં મૂકીએ છીએ:\n• ટ્રાન્સિટ અને રેસ્ટમાં ડેટાનું એનક્રિપ્શન\n• સુરક્ષિત પ્રમાણિકરણ અને ઍક્સેસ નિયંત્રણ\n• નિયમિત સુરક્ષા ઓડિટ અને અપડેટ\n• જરૂરિયાતના આધારે વ્યક્તિગત માહિતીનો મર્યાદિત ઍક્સેસ\n• ભૌતિક સુરક્ષા ઉપાયો સાથે સુરક્ષિત ડેટા સેન્ટર',
    },
    'privacyPage.section5.title': {
      'en': '5. Health Information Protection',
      'hi': '5. स्वास्थ्य जानकारी की सुरक्षा',
      'mr': '5. आरोग्य माहिती संरक्षण',
      'gu': '5. સ્વાસ્થ્ય માહિતીનું રક્ષણ',
    },
    'privacyPage.section5.body': {
      'en':
          'Your medical information is protected under strict privacy standards:\n• All health data is encrypted using industry-standard encryption\n• Access to medical records is logged and monitored\n• We comply with applicable health privacy regulations\n• Medical information is only shared with your explicit authorization',
      'hi':
          'आपकी चिकित्सा जानकारी कड़े गोपनीयता मानकों के तहत सुरक्षित है:\n• सभी स्वास्थ्य डेटा उद्योग-मानक एन्क्रिप्शन का उपयोग करके एन्क्रिप्ट किया जाता है\n• चिकित्सा रिकॉर्ड तक पहुंच लॉग और मॉनिटर की जाती है\n• हम लागू स्वास्थ्य गोपनीयता नियमों का पालन करते हैं\n• चिकित्सा जानकारी केवल आपकी स्पष्ट अनुमति से साझा की जाती है',
      'mr':
          'तुमची वैद्यकीय माहिती कठोर गोपनीयता मानकांखाली संरक्षित आहे:\n• सर्व आरोग्य डेटा उद्योग-मानक एन्क्रिप्शन वापरून एन्क्रिप्ट केला जातो\n• वैद्यकीय नोंदींमध्ये प्रवेश लॉग केला जातो आणि निरीक्षण केला जातो\n• आम्ही लागू आरोग्य गोपनीयता नियमांचे पालन करतो\n• वैद्यकीय माहिती फक्त तुमच्या स्पष्ट परवानगीने सामायिक केली जाते',
      'gu':
          'તમારી તબીબી માહિતી કડક ગોપનીયતા ધોરણો હેઠળ સુરક્ષિત છે:\n• બધા આરોગ્ય ડેટા ઉદ્યોગ-પ્રમાણભૂત એનક્રિપ્શનથી એનક્રિપ્ટ થાય છે\n• તબીબી રેકોર્ડ્સનો ઍક્સેસ લોગ અને મોનિટર કરવામાં આવે છે\n• અમે લાગુ સ્વાસ્થ્ય ગોપનીયતા નિયમોનું પાલન કરીએ છીએ\n• તબીબી માહિતી ફક્ત તમારી સ્પષ્ટ અનુમતિ સાથે શેર કરવામાં આવે છે',
    },
    'privacyPage.section6.title': {
      'en': '6. Data Retention',
      'hi': '6. डेटा प्रतिधारण',
      'mr': '6. डेटा जतन',
      'gu': '6. ડેટા જતન',
    },
    'privacyPage.section6.body': {
      'en':
          'We retain your information for as long as your account is active or as needed to provide you services. We may retain certain information for longer periods as required by law or for legitimate business purposes.',
      'hi':
          'हम आपकी जानकारी को तब तक रखते हैं जब तक आपका खाता सक्रिय है या सेवाएं प्रदान करने के लिए आवश्यक है। हम कानून द्वारा आवश्यक होने पर या वैध व्यावसायिक उद्देश्यों के लिए कुछ जानकारी को अधिक समय तक रख सकते हैं।',
      'mr':
          'आम्ही तुमची माहिती तुमचे खाते सक्रिय असताना किंवा तुम्हाला सेवा प्रदान करण्यासाठी आवश्यक तेवढी काळ ठेवतो. कायद्याने आवश्यक असल्यास किंवा वैध व्यावसायिक उद्देशांसाठी आम्ही काही माहिती अधिक काळ जतन करू शकतो.',
      'gu':
          'અમે તમારી માહિતી તેટલો સમય જાળવી રાખીએ છીએ જેટલો સમય સુધી તમારું ખાતું સક્રિય હોય છે અથવા સેવાઓ આપવા માટે જરૂરી હોય છે. કાયદા અનુસાર અથવા યોગ્ય વ્યવસાયિક હેતુઓ માટે અમુક માહિતી લાંબા સમય સુધી રાખી શકાય છે.',
    },
    'privacyPage.section7.title': {
      'en': '7. Your Rights and Choices',
      'hi': '7. आपके अधिकार और विकल्प',
      'mr': '7. तुमचे हक्क आणि पर्याय',
      'gu': '7. તમારા અધિકારો અને પસંદગીઓ',
    },
    'privacyPage.section7.body': {
      'en':
          'You have the right to:\n• Access your personal information\n• Correct inaccurate or incomplete information\n• Delete your account and associated data\n• Export your medical records\n• Withdraw consent for data processing\n• Opt out of certain communications',
      'hi':
          'आपका अधिकार है:\n• अपनी व्यक्तिगत जानकारी तक पहुँच प्राप्त करना\n• गलत या अधूरी जानकारी को सुधारना\n• अपना खाता और संबंधित डेटा हटाना\n• अपने चिकित्सा रिकॉर्ड निर्यात करना\n• डेटा प्रसंस्करण के लिए सहमति वापस लेना\n• कुछ संचारों से बाहर निकलना',
      'mr':
          'तुम्हाला अधिकार आहे:\n• तुमची वैयक्तिक माहिती प्रवेश करण्याचा\n• चुकीची किंवा अपूर्ण माहिती दुरुस्त करण्याचा\n• तुमचे खाते आणि संबंधित डेटा हटवण्याचा\n• तुमचे वैद्यकीय रेकॉर्ड निर्यात करण्याचा\n• डेटा प्रक्रियेसाठी संमती परत घेण्याचा\n• काही संप्रेषणांमधून बाहेर पडण्याचा',
      'gu':
          'તમને આ અધિકારો છે:\n• તમારી વ્યક્તિગત માહિતીનો ઍક્સેસ\n• ખોટી અથવા અધૂરી માહિતી સુધારવા\n• તમારું ખાતું અને સંબંધિત ડેટા કાઢી નાખવા\n• તમારા તબીબી રેકોર્ડ્સ નિકાસ કરવા\n• ડેટા પ્રક્રિયા માટેની સંમતિ પાછી ખેંચવા\n• કેટલીક સંચાર સેવાઓમાંથી બહાર નીકળવા',
    },
    'privacyPage.section8.title': {
      'en': '8. Cookies and Tracking Technologies',
      'hi': '8. कुकीज़ और ट्रैकिंग तकनीक',
      'mr': '8. कुकीज आणि ट्रॅकिंग तंत्रज्ञान',
      'gu': '8. કૂકીઝ અને ટ્રેકિંગ ટેકનોલોજી',
    },
    'privacyPage.section8.body': {
      'en':
          'We use cookies and similar tracking technologies to enhance your experience:\n• Essential cookies for app functionality\n• Analytics cookies to understand usage patterns\n• Security cookies to protect against fraud\n• You can control cookie settings through your device preferences',
      'hi':
          'हम आपके अनुभव को बेहतर बनाने के लिए कुकीज़ और इसी तरह की ट्रैकिंग तकनीकों का उपयोग करते हैं:\n• ऐप की कार्यक्षमता के लिए आवश्यक कुकीज़\n• उपयोग पैटर्न को समझने के लिए एनालिटिक्स कुकीज़\n• धोखाधड़ी से बचाने के लिए सुरक्षा कुकीज़\n• आप अपने डिवाइस की प्राथमिकताओं के माध्यम से कुकी सेटिंग्स को नियंत्रित कर सकते हैं',
      'mr':
          'आम्ही तुमचा अनुभव वाढवण्यासाठी कुकीज आणि समान ट्रॅकिंग तंत्रज्ञानाचा वापर करतो:\n• अॅपची कार्यक्षमता सुनिश्चित करण्यासाठी आवश्यक कुकीज\n• वापराचे नमुने समजून घेण्यासाठी विश्लेषण कुकीज\n• फसवणुकीपासून संरक्षण करण्यासाठी सुरक्षा कुकीज\n• तुम्ही तुमच्या डिव्हाइसच्या प्राधान्यांद्वारे कुकी सेटिंग्ज नियंत्रित करू शकता',
      'gu':
          'અમે તમારા અનુભવને વધારવા માટે કૂકીઝ અને સમાન ટ્રેકિંગ ટેકનોલોજીનો ઉપયોગ કરીએ છીએ:\n• ઍપની કાર્યક્ષમતા માટે આવશ્યક કૂકીઝ\n• ઉપયોગ પેટર્નને સમજવા માટે એનાલિટિક્સ કૂકીઝ\n• ફ્રોડથી બચાવવા માટે સુરક્ષા કૂકીઝ\n• તમે તમારા ઉપકરણની પ્રાથમિકતાઓ દ્વારા કૂકી સેટિંગ્સ નિયંત્રિત કરી શકો છો',
    },
    'privacyPage.section9.title': {
      'en': '9. Third-Party Services',
      'hi': '9. तृतीय-पक्ष सेवाएँ',
      'mr': '9. तृतीय-पक्ष सेवा',
      'gu': '9. તૃતીય પક્ષ સેવાઓ',
    },
    'privacyPage.section9.body': {
      'en':
          'Our application may integrate with third-party services for enhanced functionality:\n• Cloud storage providers for secure data storage\n• Analytics services for app improvement\n• Payment processors for premium features\n• All third-party integrations comply with our privacy standards',
      'hi':
          'हमारा अनुप्रयोग बेहतर कार्यक्षमता के लिए तीसरे पक्ष की सेवाओं के साथ एकीकृत हो सकता है:\n• सुरक्षित डेटा भंडारण के लिए क्लाउड स्टोरेज प्रदाता\n• ऐप सुधार के लिए एनालिटिक्स सेवाएँ\n• प्रीमियम सुविधाओं के लिए भुगतान प्रोसेसर\n• सभी तृतीय-पक्ष एकीकरण हमारे गोपनीयता मानकों का पालन करते हैं',
      'mr':
          'आमचा अनुप्रयोग कार्यक्षमता वाढवण्यासाठी तृतीय पक्ष सेवांसह एकत्रित होऊ शकतो:\n• सुरक्षित डेटा स्टोरेजसाठी क्लाउड स्टोरेज प्रदाता\n• अॅप सुधारण्यासाठी विश्लेषण सेवा\n• प्रीमियम वैशिष्ट्यांसाठी पेमेंट प्रोसेसर\n• सर्व तृतीय-पक्षील एकत्रीकरण आमच्या गोपनीयता मानकांचे पालन करतात',
      'gu':
          'અમારું ઍપ કાર્યક્ષમતા વધારવા માટે તૃતીય પક્ષ સેવાઓ સાથે સંકલિત થઈ શકે છે:\n• સુરક્ષિત ડેટા સ્ટોરેજ માટે ક્લાઉડ સ્ટોરેજ પ્રદાતા\n• ઍપ સુધારા માટે એનાલિટિક્સ સેવાઓ\n• પ્રીમિયમ સુવિધાઓ માટે પેમેન્ટ પ્રોસેસર\n• તમામ તૃતીય પક્ષ ઇન્ટેગ્રેશન અમારા ગોપનીયતા ધોરણોનું પાલન કરે છે',
    },
    'privacyPage.section10.title': {
      'en': '10. Children\'s Privacy',
      'hi': '10. बच्चों की गोपनीयता',
      'mr': '10. मुलांची गोपनीयता',
      'gu': '10. બાળકોની ગોપનીયતા',
    },
    'privacyPage.section10.body': {
      'en':
          'Our services are not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If we become aware that we have collected personal information from a child under 13, we will take steps to delete such information.',
      'hi':
          'हमारी सेवाएँ 13 वर्ष से कम उम्र के बच्चों के लिए नहीं हैं। हम जानबूझकर 13 वर्ष से कम उम्र के बच्चों से व्यक्तिगत जानकारी एकत्र नहीं करते। यदि हमें पता चलता है कि हमने 13 वर्ष से कम उम्र के किसी बच्चे से व्यक्तिगत जानकारी एकत्र की है, तो हम उस जानकारी को हटाने के लिए कदम उठाएँगे।',
      'mr':
          'आमच्या सेवा 13 वर्षांखालील मुलांसाठी नाहीत. आम्ही जाणूनबुजून 13 वर्षांखालील मुलांकडून वैयक्तिक माहिती गोळा करत नाही. जर आम्हाला कळले की आम्ही 13 वर्षांखालील मुलाकडून वैयक्तिक माहिती गोळा केली आहे, तर आम्ही ती माहिती हटवण्यासाठी पावले उचलू.',
      'gu':
          'અમારી સેવાઓ 13 વર્ષથી ઓછા બાળકો માટે નથી. અમે જાણતા 13 વર્ષથી ઓછા બાળકો પાસેથી વ્યક્તિગત માહિતી એકત્ર કરીએ નથી. જો અમને ખબર પડે કે અમે 13 વર્ષથી ઓછા બાળક પાસેથી વ્યક્તિગત માહિતી એકત્રિત કરી છે, તો અમે તે માહિતી દૂર કરવા માટે પગલાં લઈશું.',
    },
    'privacyPage.section11.title': {
      'en': '11. International Data Transfers',
      'hi': '11. अंतर्राष्ट्रीय डेटा स्थानांतरण',
      'mr': '11. आंतरराष्ट्रीय डेटा हस्तांतरण',
      'gu': '11. આંતરરાષ્ટ્રીય ડેટા ટ્રાન્સફર',
    },
    'privacyPage.section11.body': {
      'en':
          'Your information may be transferred to and processed in countries other than your own. We ensure that such transfers comply with applicable data protection laws and implement appropriate safeguards.',
      'hi':
          'आपकी जानकारी को आपके देश के अलावा अन्य देशों में स्थानांतरित किया जा सकता है और वहाँ संसाधित किया जा सकता है। हम सुनिश्चित करते हैं कि ऐसे स्थानांतरण लागू डेटा संरक्षण कानूनों का पालन करें और उचित सुरक्षा उपाय लागू हों।',
      'mr':
          'तुमची माहिती तुमच्या देशाऐवजी इतर देशांमध्ये हस्तांतरित आणि प्रक्रियेत केली जाऊ शकते. आम्ही अशा हस्तांतरणांची लागू डेटा संरक्षण कायद्यांचे पालन असल्याची आणि योग्य सुरक्षा उपायांची अंमलबजावणी आहे याची खात्री करतो.',
      'gu':
          'તમારી માહિતી તમારી દેશ સિવાયના દેશોમાં ટ્રાન્સફર અને પ્રોસેસ થઇ શકે છે. અમે ખાતરી કરીએ છીએ કે આવા ટ્રાન્સફર લાગુ ડેટા પ્રોટેક્શન કાયદાનું પાલન કરે છે અને યોગ્ય સુરક્ષા પગલાં અમલમાં મૂકવામાં આવે છે.',
    },
    'privacyPage.section12.title': {
      'en': '12. Changes to This Privacy Policy',
      'hi': '12. इस गोपनीयता नीति में बदलाव',
      'mr': '12. या गोपनीयता धोरणातील बदल',
      'gu': '12. આ ગોપનીયતા નીતિમાં બદલાવ',
    },
    'privacyPage.section12.body': {
      'en':
          'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date. We encourage you to review this Privacy Policy periodically.',
      'hi':
          'हम समय-समय पर इस गोपनीयता नीति को अपडेट कर सकते हैं। हम इस पेज पर नई गोपनीयता नीति पोस्ट करके और "अंतिम अपडेट" तारीख को अपडेट करके आपको किसी भी बदलाव की सूचना देंगे। हम आपको सलाह देते हैं कि आप इस गोपनीयता नीति की नियमित समीक्षा करें।',
      'mr':
          'आम्ही वेळोवेळी ही गोपनीयता धोरण अद्यतनित करू शकतो. आम्ही या पृष्ठावर नवीन गोपनीयता धोरण पोस्ट करून आणि "शेवटचे अद्यतन" तारीख अद्यतनित करून तुम्हाला कोणत्याही बदलांची सूचना देऊ. आम्ही तुम्हाला हे गोपनीयता धोरण नियमितपणे पुनरावलोकन करण्यास प्रोत्साहित करतो.',
      'gu':
          'અમે સમયાંતરે આ ગોપનીયતા નીતિને અપડેટ કરી શકીએ છીએ. અમે આ પાનું પર નવી ગોપનીયતા નીતિ પોસ્ટ કરીને અને "છેલ્લું અપડેટ" તારીખ અપડેટ કરીને તમને કોઈપણ ફેરફાર વિશે જાણ કરશે. અમે તમને નિયમિતપણે આ ગોપનીયતા નીતિની સમીક્ષા કરવા પ્રોત્સાહિત કરીએ છીએ.',
    },
    'privacyPage.section13.title': {
      'en': '13. Contact Us',
      'hi': '13. हमसे संपर्क करें',
      'mr': '13. आमच्याशी संपर्क साधा',
      'gu': '13. અમારો સંપર્ક કરો',
    },
    'privacyPage.section13.body': {
      'en':
          'If you have any questions about this Privacy Policy or our privacy practices, please contact us at:\nEmail: privacy@medicalvault.com\nPhone: +1 (555) 123-4567\nAddress: 123 Medical Plaza, Health City, HC 12345\nData Protection Officer: dpo@medicalvault.com',
      'hi':
          'यदि आपके पास इस गोपनीयता नीति या हमारी गोपनीयता प्रथाओं के बारे में कोई प्रश्न हैं, तो कृपया हमसे संपर्क करें:\nईमेल: privacy@medicalvault.com\nफोन: +1 (555) 123-4567\nपता: 123 मेडिकल प्लाज़ा, हेल्थ सिटी, HC 12345\nडेटा संरक्षण अधिकारी: dpo@medicalvault.com',
      'mr':
          'या गोपनीयता धोरणाबद्दल किंवा आमच्या गोपनीयता पद्धतींबद्दल तुम्हाला काही प्रश्न असल्यास, कृपया आमच्याशी संपर्क साधा:\nईमेल: privacy@medicalvault.com\nफोन: +1 (555) 123-4567\nपत्ता: 123 मेडिकल प्लाझा, हेल्थ सिटी, HC 12345\nडेटा संरक्षण अधिकारी: dpo@medicalvault.com',
      'gu':
          'જો તમને આ ગોપનીયતા નીતિ અથવા અમારી ગોપનીયતા પદ્ધતિઓ વિશે કોઈ પ્રશ્ન હોય, તો કૃપા કરીને અમારો સંપર્ક કરો:\nઇમેઇલ: privacy@medicalvault.com\nફોન: +1 (555) 123-4567\nસરનામું: 123 મેડિકલ પ્લાઝા, હેલ્થ સિટી, HC 12345\nડેટા પ્રોટેક્શન ઓફિસર: dpo@medicalvault.com',
    },
    'profile.personalInfo': {
      'en': 'Personal Information',
      'hi': 'व्यक्तिगत जानकारी',
      'mr': 'वैयक्तिक माहिती',
      'gu': 'વ્યક્તિગત માહિતી',
    },
    'profile.mobile': {
      'en': 'Mobile',
      'hi': 'मोबाइल',
      'mr': 'मोबाइल',
      'gu': 'મોબાઈલ',
    },
    'profile.aadhaar': {
      'en': 'Aadhaar',
      'hi': 'आधार',
      'mr': 'आधार',
      'gu': 'આધાર',
    },
    'profile.dob': {
      'en': 'DOB',
      'hi': 'जन्म तिथि',
      'mr': 'जन्मतारीख',
      'gu': 'જન્મ તારીખ',
    },
    'profile.healthInfo': {
      'en': 'Health Information',
      'hi': 'स्वास्थ्य जानकारी',
      'mr': 'आरोग्य माहिती',
      'gu': 'સ્વાસ્થ્ય માહિતી',
    },
    'profile.gender': {
      'en': 'Gender',
      'hi': 'लिंग',
      'mr': 'लिंग',
      'gu': 'લિંગ',
    },
    'profile.bloodType': {
      'en': 'Blood Type',
      'hi': 'रक्त समूह',
      'mr': 'रक्त गट',
      'gu': 'રક્તનો પ્રકાર',
    },
    'profile.allergies': {
      'en': 'Allergies',
      'hi': 'एलर्जी',
      'mr': 'अॅलर्जी',
      'gu': 'ઍલર્જી',
    },
    'profile.height': {
      'en': 'Height',
      'hi': 'ऊँचाई',
      'mr': 'उंची',
      'gu': 'ઉંચાઈ',
    },
    'profile.weight': {
      'en': 'Weight',
      'hi': 'वजन',
      'mr': 'वजन',
      'gu': 'વજન',
    },
    'profile.lastVisit': {
      'en': 'Last Visit',
      'hi': 'अंतिम मुलाकात',
      'mr': 'शेवटची भेट',
      'gu': 'છેલ્લી મુલાકાત',
    },
    'profile.nextAppointment': {
      'en': 'Next Appointment',
      'hi': 'अगली नियुक्ति',
      'mr': 'पुढील भेट',
      'gu': 'આગામી મુલાકાત',
    },
    'profile.emergencyContact': {
      'en': 'Emergency Contact',
      'hi': 'आपातकालीन संपर्क',
      'mr': 'आपत्कालीन संपर्क',
      'gu': 'તાકીદનો સંપર્ક',
    },
    'profile.emergencyName': {
      'en': 'Name',
      'hi': 'नाम',
      'mr': 'नाव',
      'gu': 'નામ',
    },
    'profile.emergencyRelationship': {
      'en': 'Relationship',
      'hi': 'संबंध',
      'mr': 'नाते',
      'gu': 'સંબંધ',
    },
    'profile.emergencyPhone': {
      'en': 'Phone',
      'hi': 'फ़ोन',
      'mr': 'फोन',
      'gu': 'ફોન',
    },
    'profile.medicalHistory': {
      'en': 'Medical History',
      'hi': 'चिकित्सा इतिहास',
      'mr': 'वैद्यकीय इतिहास',
      'gu': 'તબીબી ઇતિહાસ',
    },
    'profile.medications': {
      'en': 'Medications',
      'hi': 'दवाइयाँ',
      'mr': 'औषधे',
      'gu': 'દવાઓ',
    },
    'profile.medicalRecords': {
      'en': 'Medical Records',
      'hi': 'चिकित्सा रिकॉर्ड',
      'mr': 'वैद्यकीय नोंदी',
      'gu': 'તબીબી રેકોર્ડ',
    },
    'profile.noData': {
      'en': 'No data available',
      'hi': 'कोई डेटा उपलब्ध नहीं',
      'mr': 'माहिती उपलब्ध नाही',
      'gu': 'કોઈ માહિતી ઉપલબ્ધ નથી',
    },
    'profile.noRecords': {
      'en': 'No records available',
      'hi': 'कोई रिकॉर्ड उपलब्ध नहीं',
      'mr': 'नोंदी उपलब्ध नाहीत',
      'gu': 'કોઈ રેકોર્ડ ઉપલબ્ધ નથી',
    },
    'profile.unknownDate': {
      'en': 'Unknown date',
      'hi': 'अज्ञात तिथि',
      'mr': 'अज्ञात तारीख',
      'gu': 'અજ્ઞાત તારીખ',
    },
    'profile.unknownType': {
      'en': 'Unknown type',
      'hi': 'अज्ञात प्रकार',
      'mr': 'अज्ञात प्रकार',
      'gu': 'અજ્ઞાત પ્રકાર',
    },
    'profile.medicalHistoryDeleted': {
      'en': 'Medical history deleted',
      'hi': 'चिकित्सा इतिहास हटाया गया',
      'mr': 'वैद्यकीय इतिहास हटवला',
      'gu': 'તબીબી ઇતિહાસ દૂર કર્યો',
    },
    'profile.addMedicalHistory': {
      'en': 'Add Medical History',
      'hi': 'चिकित्सा इतिहास जोड़ें',
      'mr': 'वैद्यकीय इतिहास जोडा',
      'gu': 'તબીબી ઇતિહાસ ઉમેરો',
    },
    'profile.medicationsTitle': {
      'en': 'Medications',
      'hi': 'दवाइयाँ',
      'mr': 'औषधे',
      'gu': 'દવાઓ',
    },
    'profile.medicationDeleted': {
      'en': 'Medication deleted',
      'hi': 'दवाई हटाई गई',
      'mr': 'औषध हटवले',
      'gu': 'દવા દૂર કરાઈ',
    },
    'profile.addMedication': {
      'en': 'Add Medication',
      'hi': 'दवाई जोड़ें',
      'mr': 'औषध जोडा',
      'gu': 'દવા ઉમેરો',
    },
    'profile.medicalHistory.dialogTitle': {
      'en': 'Add Medical History',
      'hi': 'चिकित्सा इतिहास जोड़ें',
      'mr': 'वैद्यकीय इतिहास जोडा',
      'gu': 'તબીબી ઇતિહાસ ઉમેરો',
    },
    'profile.medicalHistory.condition': {
      'en': 'Condition',
      'hi': 'स्थिति',
      'mr': 'स्थिती',
      'gu': 'પરિસ્થિતિ',
    },
    'profile.medicalHistory.status': {
      'en': 'Status (active / resolved / chronic)',
      'hi': 'स्थिति (सक्रिय / हल / दीर्घकालिक)',
      'mr': 'स्थिती (सक्रिय / निराकरण / दीर्घकालीन)',
      'gu': 'સ્થિતિ (સક્રિય / ઉકેલાયેલ / ક્રોનિક)',
    },
    'profile.medications.dialogTitle': {
      'en': 'Add Medication',
      'hi': 'दवाई जोड़ें',
      'mr': 'औषध जोडा',
      'gu': 'દવા ઉમેરો',
    },
    'profile.medications.nameLabel': {
      'en': 'Medicine Name',
      'hi': 'दवा का नाम',
      'mr': 'औषधाचे नाव',
      'gu': 'દવાની નામ',
    },
    'profile.medications.dosageLabel': {
      'en': 'Dosage',
      'hi': 'खुराक',
      'mr': 'डोस',
      'gu': 'ડોઝ',
    },
    'profile.medications.frequencyLabel': {
      'en': 'Frequency',
      'hi': 'आवृत्ति',
      'mr': 'वारंवारता',
      'gu': 'આવર્તન',
    },
    'profile.editButton': {
      'en': 'Edit Profile',
      'hi': 'प्रोफ़ाइल संपादित करें',
      'mr': 'प्रोफाइल संपादित करा',
      'gu': 'પ્રોફાઇલ સંપાદિત કરો',
    },
    'profile.saveChanges': {
      'en': 'Save Changes',
      'hi': 'परिवर्तन सहेजें',
      'mr': 'बदल जतन करा',
      'gu': 'ફેરફારો સાચવો',
    },
    'profile.updateFailed': {
      'en': 'Could not update profile. Please try again.',
      'hi': 'प्रोफ़ाइल अपडेट नहीं हो सका। कृपया पुनः प्रयास करें।',
      'mr': 'प्रोफाइल अद्यतन करू शकलो नाही. कृपया पुन्हा प्रयत्न करा.',
      'gu': 'પ્રોફાઇલ અપડેટ થઈ શક્યું નહીં. કૃપા કરીને ફરી પ્રયાસ કરો.',
    },
    'profile.photo.change': {
      'en': 'Change Photo',
      'hi': 'फ़ोटो बदलें',
      'mr': 'फोटो बदला',
      'gu': 'ફોટો બદલો',
    },
    'profile.photo.updated': {
      'en': 'Profile photo updated',
      'hi': 'प्रोफ़ाइल फ़ोटो अपडेट किया गया',
      'mr': 'प्रोफाइल फोटो अद्यतन झाला',
      'gu': 'પ્રોફાઇલ ફોટો અપડેટ થયો',
    },
    'profile.photo.updateFailed': {
      'en': 'Could not update profile photo.',
      'hi': 'प्रोफ़ाइल फ़ोटो अपडेट नहीं हो सका।',
      'mr': 'प्रोफाइल फोटो अद्यतन करू शकलो नाही.',
      'gu': 'પ્રોફાઇલ ફોટો અપડેટ થઈ શક્યો નહીં.',
    },
    'profile.photo.uploadFailed': {
      'en': 'Photo upload failed.',
      'hi': 'फ़ोटो अपलोड विफल रहा।',
      'mr': 'फोटो अपलोड अयशस्वी झाला.',
      'gu': 'ફોટો અપલોડ નિષ્ફળ રહ્યો.',
    },
    'profile.photo.camera': {
      'en': 'Take Photo',
      'hi': 'फ़ोटो लें',
      'mr': 'फोटो घ्या',
      'gu': 'ફોટો લો',
    },
    'profile.photo.gallery': {
      'en': 'Choose from Gallery',
      'hi': 'गैलरी से चुनें',
      'mr': 'गॅलरीमधून निवडा',
      'gu': 'ગેલેરીમાંથી પસંદ કરો',
    },
    'profile.editTitle': {
      'en': 'Edit Profile',
      'hi': 'प्रोफ़ाइल संपादित करें',
      'mr': 'प्रोफाइल संपादित करा',
      'gu': 'પ્રોફાઇલ સંપાદિત કરો',
    },
    'profile.editAll': {
      'en': 'Edit All Fields',
      'hi': 'सभी फ़ील्ड संपादित करें',
      'mr': 'सर्व फील्ड संपादित करा',
      'gu': 'બધા ફીલ્ડ સંપાદિત કરો',
    },
    'profile.quickEdit': {
      'en': 'Quick Edit',
      'hi': 'त्वरित संपादन',
      'mr': 'त्वरित संपादन',
      'gu': 'ઝડપી સંપાદન',
    },
    'profile.quickEdit.title': {
      'en': 'Edit Field',
      'hi': 'फ़ील्ड संपादित करें',
      'mr': 'फील्ड संपादित करा',
      'gu': 'ફીલ્ડ સંપાદિત કરો',
    },
    'profile.quickEdit.fieldLabel': {
      'en': 'Edit {field}',
      'hi': '{field} संपादित करें',
      'mr': '{field} संपादित करा',
      'gu': '{field} સંપાદિત કરો',
    },
    'profile.deleteItem.title': {
      'en': 'Delete Item',
      'hi': 'आइटम हटाएं',
      'mr': 'आयटम हटवा',
      'gu': 'આઇટમ કાઢી નાખો',
    },
    'profile.deleteItem.message': {
      'en':
          'Are you sure you want to delete "{itemName}"? This action cannot be undone.',
      'hi':
          'क्या आप वाकई "{itemName}" को हटाना चाहते हैं? यह कार्रवाई पूर्ववत नहीं की जा सकती।',
      'mr':
          'तुम्हाला खरोखर "{itemName}" हटवायची आहे का? ही क्रिया पूर्ववत करता येत नाही.',
      'gu':
          'શું તમે ખરેખર "{itemName}" કાઢી નાખવા માંગો છો? આ ક્રિયા પૂર્વવત્ કરી શકાતી નથી.',
    },
    'profile.updateSuccess': {
      'en': 'Profile updated successfully',
      'hi': 'प्रोफ़ाइल सफलतापूर्वक अपडेट किया गया',
      'mr': 'प्रोफाइल यशस्वीरित्या अद्यतन झाले',
      'gu': 'પ્રોફાઇલ સફળતાપૂર્વક અપડેટ થયું',
    },
    'profile.addSuccess': {
      'en': 'Item added successfully',
      'hi': 'आइटम सफलतापूर्वक जोड़ा गया',
      'mr': 'आयटम यशस्वीरित्या जोडले',
      'gu': 'આઇટમ સફળતાપૂર્વક ઉમેરાયું',
    },
    'profile.deleteSuccess': {
      'en': 'Item deleted successfully',
      'hi': 'आइटम सफलतापूर्वक हटाया गया',
      'mr': 'आयटम यशस्वीरित्या हटवले',
      'gu': 'આઇટમ સફળતાપૂર્વક કાઢી નાખ્યું',
    },
    'profile.deleteFailed': {
      'en': 'Failed to delete item',
      'hi': 'आइटम हटाने में विफल',
      'mr': 'आयटम हटवण्यात अयशस्वी',
      'gu': 'આઇટમ કાઢવામાં નિષ્ફળ',
    },
    'profile.medicalHistory.editTitle': {
      'en': 'Edit Medical History',
      'hi': 'चिकित्सा इतिहास संपादित करें',
      'mr': 'वैद्यकीय इतिहास संपादित करा',
      'gu': 'તબીબી ઇતિહાસ સંપાદિત કરો',
    },
    'profile.medications.editTitle': {
      'en': 'Edit Medication',
      'hi': 'दवा संपादित करें',
      'mr': 'औषध संपादित करा',
      'gu': 'દવા સંપાદિત કરો',
    },
    'forgotPassword.title': {
      'en': 'Forgot Password',
      'hi': 'पासवर्ड भूल गए',
      'mr': 'पासवर्ड विसरलात',
      'gu': 'પાસવર્ડ ભૂલી ગયા',
    },
    'forgotPassword.instructions': {
      'en': 'Enter your email to receive a reset link',
      'hi': 'रीसेट लिंक प्राप्त करने के लिए अपना ईमेल दर्ज करें',
      'mr': 'रीसेट लिंक मिळवण्यासाठी तुमचा ईमेल प्रविष्ट करा',
      'gu': 'રીસેટ લિંક મેળવવા માટે તમારો ઇમેઇલ દાખલ કરો',
    },
    'forgotPassword.emailLabel': {
      'en': 'Email',
      'hi': 'ईमेल',
      'mr': 'ईमेल',
      'gu': 'ઈમેલ',
    },
    'forgotPassword.enterEmail': {
      'en': 'Please enter your email',
      'hi': 'कृपया अपना ईमेल दर्ज करें',
      'mr': 'कृपया तुमचा ईमेल प्रविष्ट करा',
      'gu': 'કૃપા કરીને તમારો ઇમેલ દાખલ કરો',
    },
    'forgotPassword.sendLink': {
      'en': 'Send Reset Link',
      'hi': 'रीसेट लिंक भेजें',
      'mr': 'रीसेट लिंक पाठवा',
      'gu': 'રીસેટ લિંક મોકલો',
    },
    'forgotPassword.successFallback': {
      'en': 'If your email exists, a reset link has been sent.',
      'hi': 'यदि आपका ईमेल मौजूद है, तो रीसेट लिंक भेज दिया गया है।',
      'mr': 'जर तुमचा ईमेल अस्तित्वात असेल तर रीसेट लिंक पाठवली आहे.',
      'gu': 'જો તમારો ઇમેલ અસ્તિત્વમાં હશે તો રીસેટ લિંક મોકલાઈ છે.',
    },
    'forgotPassword.failureFallback': {
      'en': 'Failed to send reset email. Please try again.',
      'hi': 'रीसेट ईमेल भेजने में विफल। कृपया पुनः प्रयास करें।',
      'mr': 'रीसेट ईमेल पाठवण्यात अयशस्वी. कृपया पुन्हा प्रयत्न करा.',
      'gu': 'રીસેટ ઇમેલ મોકલવામાં નિષ્ફળ. કૃપા કરીને ફરી પ્રયાસ કરો.',
    },
    'resetPassword.title': {
      'en': 'Reset Password',
      'hi': 'पासवर्ड रीसेट करें',
      'mr': 'पासवर्ड रीसेट करा',
      'gu': 'પાસવર્ડ ફરીથી સેટ કરો',
    },
    'resetPassword.subtitle': {
      'en': 'Create a new password',
      'hi': 'नया पासवर्ड बनाएं',
      'mr': 'नवीन पासवर्ड तयार करा',
      'gu': 'નવો પાસવર્ડ બનાવો',
    },
    'resetPassword.newPassword': {
      'en': 'New Password',
      'hi': 'नया पासवर्ड',
      'mr': 'नवीन पासवर्ड',
      'gu': 'નવો પાસવર્ડ',
    },
    'resetPassword.confirmPassword': {
      'en': 'Confirm Password',
      'hi': 'पासवर्ड की पुष्टि करें',
      'mr': 'पासवर्ड पुष्टी करा',
      'gu': 'પાસવર્ડની પુષ્ટિ કરો',
    },
    'resetPassword.button': {
      'en': 'Reset Password',
      'hi': 'पासवर्ड रीसेट करें',
      'mr': 'पासवर्ड रीसेट करा',
      'gu': 'પાસવર્ડ ફરીથી સેટ કરો',
    },
    'resetPassword.missingToken': {
      'en': 'Reset token missing. Open the link from email.',
      'hi': 'रीसेट टोकन अनुपलब्ध है। कृपया ईमेल से लिंक खोलें।',
      'mr': 'रीसेट टोकन उपलब्ध नाही. कृपया ईमेलमधून लिंक उघडा.',
      'gu': 'રીસેટ ટોકન ઉપલબ્ધ નથી. કૃપા કરીને ઇમેઇલથી લિંક ખોલો.',
    },
    'resetPassword.minLength': {
      'en': 'Password must be at least 6 characters',
      'hi': 'पासवर्ड कम से कम 6 अक्षर का होना चाहिए',
      'mr': 'पासवर्ड किमान 6 अक्षरांचा असावा',
      'gu': 'પાસવર્ડ ઓછામાં ઓછો 6 અક્ષરોનો હોવો જોઈએ',
    },
    'resetPassword.mismatch': {
      'en': 'Passwords do not match',
      'hi': 'पासवर्ड मेल नहीं खाते',
      'mr': 'पासवर्ड जुळत नाहीत',
      'gu': 'પાસવર્ડ મેળ ખાતા નથી',
    },
    'resetPassword.successFallback': {
      'en': 'Password reset successfully. Please sign in.',
      'hi': 'पासवर्ड सफलतापूर्वक रीसेट हो गया। कृपया साइन इन करें।',
      'mr': 'पासवर्ड यशस्वीपणे रीसेट झाला. कृपया साइन इन करा.',
      'gu': 'પાસવર્ડ સફળતાપૂર્વક રીસેટ થયો. કૃપા કરી સાઇન ઇન કરો.',
    },
    'resetPassword.failureFallback': {
      'en': 'Failed to reset password. The link may be expired.',
      'hi': 'पासवर्ड रीसेट करने में विफल। लिंक की समय सीमा समाप्त हो सकती है।',
      'mr': 'पासवर्ड रीसेट करण्यात अयशस्वी. लिंक कालबाह्य झाली असू शकते.',
      'gu': 'પાસવર્ડ રીસેટ કરવામાં નિષ્ફળ. લિંક સમાપ્ત થઈ હશે.',
    },
    'dashboard.greeting': {
      'en': 'Hello, {name} 👋',
      'hi': 'नमस्ते, {name} 👋',
      'mr': 'नमस्कार, {name} 👋',
      'gu': 'નમસ્તે, {name} 👋',
    },
    'dashboard.profileCount': {
      'en': '{count} profiles available',
      'hi': '{count} प्रोफ़ाइल उपलब्ध',
      'mr': '{count} प्रोफाइल उपलब्ध',
      'gu': '{count} પ્રોફાઇલ ઉપલબ્ધ',
    },
    'dashboard.switchProfileTooltip': {
      'en': 'Switch Profile',
      'hi': 'प्रोफ़ाइल बदलें',
      'mr': 'प्रोफाइल बदला',
      'gu': 'પ્રોફાઇલ બદલો',
    },
    'dashboard.quickActions': {
      'en': 'Quick Actions',
      'hi': 'त्वरित क्रियाएँ',
      'mr': 'त्वरित क्रिया',
      'gu': 'ઝડપી ક્રિયા',
    },
    'dashboard.action.generateShareQR': {
      'en': 'Generate\nShare QR',
      'hi': 'QR साझा\nबनाएँ',
      'mr': 'QR शेअर\nतयार करा',
      'gu': 'QR શેર\nબનાવો',
    },
    'dashboard.action.accessRequests': {
      'en': 'Access\nRequests',
      'hi': 'प्रवेश\nअनुरोध',
      'mr': 'प्रवेश\nविनंत्या',
      'gu': 'ઍક્સેસ\nવિનંતીઓ',
    },
    'dashboard.action.emergencySOS': {
      'en': 'Emergency\nSOS',
      'hi': 'आपातकालीन\nSOS',
      'mr': 'आपत्कालीन\nSOS',
      'gu': 'આપાતકાલીન\nSOS',
    },
    'dashboard.action.reportLostPerson': {
      'en': 'Report\nLost Person',
      'hi': 'लापता व्यक्ति\nरिपोर्ट करें',
      'mr': 'हरवलेली व्यक्ती\nरिपोर्ट करा',
      'gu': 'ગુમ થયેલી વ્યક્તિ\nરિપોર્ટ કરો',
    },
    'dashboard.action.reportFoundPerson': {
      'en': 'Report\nFound Person',
      'hi': 'मिली हुई व्यक्ति\nरिपोर्ट करें',
      'mr': 'सापडलेली व्यक्ती\nरिपोर्ट करा',
      'gu': 'મળેલી વ્યક્તિ\nરિપોર્ટ કરો',
    },
    'dashboard.action.myLostReports': {
      'en': 'My Lost\nReports',
      'hi': 'मेरी खोई हुई\nरिपोर्टें',
      'mr': 'माझे हरवलेले\nरिपोर्ट',
      'gu': 'મારી ગુમ થયેલી\nરિપોર્ટ્સ',
    },
    'dashboard.documentsTitle': {
      'en': 'My Documents',
      'hi': 'मेरे दस्तावेज़',
      'mr': 'माझी कागदपत्रे',
      'gu': 'મારા દસ્તાવેજો',
    },
    'dashboard.documentsTotal': {
      'en': '{count} total',
      'hi': 'कुल {count}',
      'mr': 'एकूण {count}',
      'gu': 'કુલ {count}',
    },
    'dashboard.documentSingular': {
      'en': 'document',
      'hi': 'दस्तावेज़',
      'mr': 'दस्तऐवज',
      'gu': 'દસ્તાવેજ',
    },
    'dashboard.documentPlural': {
      'en': 'documents',
      'hi': 'दस्तावेज़',
      'mr': 'दस्तऐवज',
      'gu': 'દસ્તાવેજો',
    },
    'documents.category.reports': {
      'en': 'Reports',
      'hi': 'रिपोर्ट',
      'mr': 'अहवाल',
      'gu': 'અહેવાલ',
    },
    'documents.category.prescriptions': {
      'en': 'Prescriptions',
      'hi': 'प्रिस्क्रिप्शन',
      'mr': 'प्रिस्क्रिप्शन',
      'gu': 'પ્રિસ્ક્રિપ્શન',
    },
    'documents.category.bills': {
      'en': 'Bills',
      'hi': 'बिल',
      'mr': 'बिले',
      'gu': 'બિલ્સ',
    },
    'documents.category.insurance': {
      'en': 'Insurance Details',
      'hi': 'बीमा विवरण',
      'mr': 'विमा तपशील',
      'gu': 'વીમા વિગતો',
    },
    'dashboard.alert.massSOS': {
      'en': 'Mass SOS detected near your location',
      'hi': 'आपके पास बड़े पैमाने पर SOS का पता चला',
      'mr': 'आपल्या स्थानाजवळ मोठ्या प्रमाणात SOS आढळले',
      'gu': 'તમારા નજીક મોટા પાયે SOS મળ્યો છે',
    },
    'dashboard.alert.waterQuality': {
      'en': 'Water quality is getting impure',
      'hi': 'पानी की गुणवत्ता खराब हो रही है',
      'mr': 'पाण्याची गुणवत्ता खालावत आहे',
      'gu': 'પાણીની ગુણવત્તા ખરાબ થઈ રહી છે',
    },
    'dashboard.alert.unusualActivity': {
      'en': 'Unusual activity reported in shared accounts',
      'hi': 'साझा खातों में असामान्य गतिविधि दर्ज की गई',
      'mr': 'सामायिक खात्यांमध्ये अनियमित कृती नोंदली गेली',
      'gu': 'સાંઝા खातાઓમાં અસાધારણ પ્રવૃત્તિ નોંધાઈ છે',
    },
    'dashboard.nav.home': {
      'en': 'Home',
      'hi': 'होम',
      'mr': 'मुख्यपृष्ठ',
      'gu': 'હોમ',
    },
    'dashboard.nav.vault': {
      'en': 'Vault',
      'hi': 'वॉल्ट',
      'mr': 'व्हॉल्ट',
      'gu': 'વૉલ્ટ',
    },
    'dashboard.nav.qr': {
      'en': 'QR',
      'hi': 'क्यूआर',
      'mr': 'क्यूआर',
      'gu': 'ક્યુઆર',
    },
    'dashboard.nav.requests': {
      'en': 'Requests',
      'hi': 'अनुरोध',
      'mr': 'विनंत्या',
      'gu': 'વિનંતીઓ',
    },
    'dashboard.nav.settings': {
      'en': 'Settings',
      'hi': 'सेटिंग्स',
      'mr': 'सेटिंग्ज',
      'gu': 'સેટિંગ્સ',
    },
    'dashboard.exitDialog.title': {
      'en': 'Exit App',
      'hi': 'ऐप से बाहर निकलें',
      'mr': 'ऍप बंद करा',
      'gu': 'એપ બંધ કરો',
    },
    'dashboard.exitDialog.message': {
      'en': 'Are you sure you want to exit the app?',
      'hi': 'क्या आप वाकई ऐप से बाहर निकलना चाहते हैं?',
      'mr': 'आपण खात्रीने ऍप बंद करू इच्छिता?',
      'gu': 'શું તમે ખરેખર એપ બંધ કરવા માંગો છો?',
    },
    'dashboard.exitDialog.confirm': {
      'en': 'Exit',
      'hi': 'बाहर निकलें',
      'mr': 'बाहेर पडा',
      'gu': 'બહાર નીકળો',
    },
    'chat.title': {
      'en': 'AI Assistant 🤖',
      'hi': 'एआई सहायक 🤖',
      'mr': 'एआय सहाय्यक 🤖',
      'gu': 'એઆઈ સહાયક 🤖',
    },
    'chat.tooltip.clear': {
      'en': 'Clear Chat',
      'hi': 'चैट साफ़ करें',
      'mr': 'चॅट साफ करा',
      'gu': 'ચેટ સાફ કરો',
    },
    'chat.welcome.greeting': {
      'en':
          "Hello! I'm your Medical Vault AI Assistant 🤖 How can I help you today?",
      'hi':
          'नमस्ते! मैं आपका मेडिकल वॉल्ट एआई सहायक हूं 🤖 आज मैं आपकी कैसे मदद कर सकता हूँ?',
      'mr':
          'नमस्कार! मी तुमचा मेडिकल वॉल्ट एआय सहाय्यक आहे 🤖 आज मी तुम्हाला कशी मदत करू?',
      'gu':
          'નમસ્તે! હું તમારો મેડિકલ વોલ્ટ એઆઈ સહાયક છું 🤖 આજે હું તમને કેવી રીતે મદદ કરી શકું?',
    },
    'chat.welcome.helper': {
      'en':
          'I can analyze your documents, provide insights, and answer in multiple languages. Please log in first to access your medical documents and get personalized assistance!',
      'hi':
          'मैं आपके दस्तावेज़ों का विश्लेषण कर सकता हूँ, जानकारी दे सकता हूँ और कई भाषाओं में उत्तर दे सकता हूँ। कृपया व्यक्तिगत सहायता के लिए पहले लॉग इन करें!',
      'mr':
          'मी तुमची कागदपत्रे विश्लेषित करू शकतो, माहिती देऊ शकतो आणि अनेक भाषांमध्ये उत्तर देऊ शकतो. वैयक्तिक मदतीसाठी कृपया आधी लॉगिन करा!',
      'gu':
          'હું તમારા દસ્તાવેજોનું વિશ્લેષણ કરી શકું છું, માહિતી આપી શકું છું અને અનેક ભાષામાં જવાબ આપી શકું છું. વ્યક્તિગત સહાય માટે કૃપા કરીને પહેલાં લોગિન કરો!',
    },
    'chat.autoAnalyze': {
      'en': 'I see you want to analyze: {name}. Let me help you with that!',
      'hi':
          'मैं देख रहा हूँ कि आप {name} का विश्लेषण करना चाहते हैं। मैं आपकी मदद करता हूँ!',
      'mr':
          'मी पाहत आहे की तुम्हाला {name} चे विश्लेषण करायचे आहे. मी तुमची मदत करतो!',
      'gu':
          'હું જોઈ રહ્યો છું કે તમે {name}નું વિશ્લેષણ કરવા માંગો છો. હું તમને મદદ કરું!',
    },
    'chat.loginRequired': {
      'en':
          '🔐 Please log in to use the AI Assistant!\n\nYou can log in from the Settings page or by tapping the profile icon. Once logged in, I can help you analyze your medical documents and answer questions about your health records.\n\n💡 Tip: Use the navigation bar to go to Settings and log in with your credentials.',
      'hi':
          '🔐 एआई सहायक का उपयोग करने के लिए कृपया लॉग इन करें!\n\nआप सेटिंग्स पेज से या प्रोफ़ाइल आइकन पर टैप करके लॉग इन कर सकते हैं। लॉग इन करने के बाद मैं आपके चिकित्सा दस्तावेज़ों का विश्लेषण कर सकता हूँ और स्वास्थ्य रिकॉर्ड से जुड़े सवालों के जवाब दे सकता हूँ।\n\n💡 सुझाव: नेविगेशन बार से सेटिंग्स पर जाएँ और अपनी जानकारी के साथ लॉग इन करें।',
      'mr':
          '🔐 एआय सहाय्यक वापरण्यासाठी कृपया लॉगिन करा!\n\nआपण सेटिंग्ज पृष्ठातून किंवा प्रोफाइल आयकॉनवर टॅप करून लॉगिन करू शकता. लॉगिन केल्यानंतर मी तुमची वैद्यकीय कागदपत्रे विश्लेषित करून आरोग्य नोंदींबद्दलच्या प्रश्नांची उत्तरे देऊ शकतो.\n\n💡 टिप: नेव्हिगेशन बारमधून सेटिंग्जवर जा आणि तुमच्या तपशीलांसह लॉगिन करा.',
      'gu':
          '🔐 એઆઈ સહાયકનો ઉપયોગ કરવા માટે કૃપા કરીને લૉગિન કરો!\n\nતમે સેટિંગ્સ પેજમાંથી અથવા પ્રોફાઇલ આઇકન પર ટૅપ કરીને લૉગિન કરી શકો છો. લૉગિન પછી હું તમારા તબીબી દસ્તાવેજોનું વિશ્લેષણ કરી શકું છું અને આરોગ્ય રેકોર્ડ વિષયક પ્રશ્નોના જવાબ આપી શકું છું.\n\n💡 સૂચન: નેવિગેશન બારમાંથી સેટિંગ્સ પર જઈને તમારી ઓળખ સાથે લૉગિન કરો.',
    },
    'chat.error.generic': {
      'en': 'Sorry, I encountered an error. Please try again.',
      'hi': 'क्षमा करें, एक त्रुटि हुई। कृपया पुनः प्रयास करें।',
      'mr': 'क्षमस्व, एक त्रुटी आली. कृपया पुन्हा प्रयत्न करा.',
      'gu': 'માફ કરશો, કોઈ ભૂલ આવી. કૃપા કરીને ફરી પ્રયાસ કરો.',
    },
    'chat.error.analysis': {
      'en': 'Sorry, I encountered an error while analyzing the document.',
      'hi': 'क्षमा करें, दस्तावेज़ का विश्लेषण करते समय त्रुटि हुई।',
      'mr': 'क्षमस्व, दस्तऐवज विश्लेषित करताना त्रुटी आली.',
      'gu': 'માફ કરશો, દસ્તાવેજનું વિશ્લેષણ કરતી વખતે ભૂલ આવી.',
    },
    'chat.userAnalyzePrompt': {
      'en': 'Analyze this document: {name}',
      'hi': 'इस दस्तावेज़ का विश्लेषण करें: {name}',
      'mr': 'हा दस्तऐवज विश्लेषित करा: {name}',
      'gu': 'આ દસ્તાવેજનું વિશ્લેષણ કરો: {name}',
    },
    'chat.aiAnalyzePrompt': {
      'en': 'Please analyze this document and provide insights',
      'hi': 'कृपया इस दस्तावेज़ का विश्लेषण करें और जानकारी दें',
      'mr': 'कृपया हा दस्तऐवज विश्लेषित करून माहिती द्या',
      'gu': 'કૃપા કરીને આ દસ્તાવેજનું વિશ્લેષણ કરીને જાણકારી આપો',
    },
    'chat.documentsLabel': {
      'en': 'Documents:',
      'hi': 'दस्तावेज़:',
      'mr': 'दस्तऐवज:',
      'gu': 'દસ્તાવેજો:',
    },
    'chat.clearDialog.title': {
      'en': 'Clear Chat',
      'hi': 'चैट साफ़ करें',
      'mr': 'चॅट साफ करा',
      'gu': 'ચેટ સાફ કરો',
    },
    'chat.clearDialog.message': {
      'en':
          'Are you sure you want to clear all chat messages? This action cannot be undone.',
      'hi':
          'क्या आप वाकई सभी चैट संदेश हटाना चाहते हैं? यह क्रिया वापस नहीं की जा सकती।',
      'mr':
          'तुम्हाला खरंच सर्व चॅट संदेश हटवायचे आहेत का? ही कृती पूर्ववत करता येणार नाही.',
      'gu':
          'શું તમે ખરેખર બધા ચેટ સંદેશા સાફ કરવા માંગો છો? આ ક્રિયા પાછી નહીં કરી શકાય.',
    },
    'chat.clearDialog.confirm': {
      'en': 'Clear',
      'hi': 'साफ़ करें',
      'mr': 'साफ करा',
      'gu': 'સાફ કરો',
    },
    'chat.inputHint.english': {
      'en': 'Ask me about your health records...',
      'hi': 'Ask me about your health records...',
      'mr': 'Ask me about your health records...',
      'gu': 'Ask me about your health records...',
    },
    'chat.inputHint.hindi': {
      'en': 'अपने स्वास्थ्य रिकॉर्ड के बारे में पूछें...',
      'hi': 'अपने स्वास्थ्य रिकॉर्ड के बारे में पूछें...',
      'mr': 'अपने स्वास्थ्य रिकॉर्ड के बारे में पूछें...',
      'gu': 'अपने स्वास्थ्य रिकॉर्ड के बारे में पूछें...',
    },
    'chat.inputHint.marathi': {
      'en': 'तुमच्या आरोग्य नोंदींबद्दल विचारा...',
      'hi': 'तुमच्या आरोग्य नोंदींबद्दल विचारा...',
      'mr': 'तुमच्या आरोग्य नोंदींबद्दल विचारा...',
      'gu': 'तुमच्या आरोग्य नोंदींबद्दल विचारा...',
    },
    'chat.inputHint.hinglish': {
      'en': 'Apne health records ke baare mein poochhein...',
      'hi': 'Apne health records ke baare mein poochhein...',
      'mr': 'Apne health records ke baare mein poochhein...',
      'gu': 'Apne health records ke baare mein poochhein...',
    },
    'dashboard.promo.stayHydratedTitle': {
      'en': 'Stay Hydrated',
      'hi': 'हाइड्रेटेड रहें',
      'mr': 'हायड्रेटेड रहा',
      'gu': 'હાઇડ્રેટેડ રહો',
    },
    'dashboard.promo.stayHydratedSubtitle': {
      'en': 'Drink water regularly to improve wellness',
      'hi': 'स्वास्थ्य बेहतर बनाने के लिए नियमित रूप से पानी पिएँ',
      'mr': 'आरोग्य सुधारण्यासाठी नियमित पाणी प्या',
      'gu': 'તમારા સ્વાસ્થ્ય માટે નિયમિત પાણી પીવો',
    },
    'dashboard.promo.secureBackupTitle': {
      'en': 'Secure Backup',
      'hi': 'सुरक्षित बैकअप',
      'mr': 'सुरक्षित बॅकअप',
      'gu': 'સુરક્ષિત બેકઅપ',
    },
    'dashboard.promo.secureBackupSubtitle': {
      'en': 'Back up your health docs to avoid loss',
      'hi': 'नुकसान से बचने के लिए अपने स्वास्थ्य दस्तावेज़ों का बैकअप लें',
      'mr': 'नुकसान टाळण्यासाठी तुमची आरोग्य कागदपत्रे बॅकअप करा',
      'gu': 'નુકસાન ટાળવા તમારા હેલ્થ દસ્તાવેજોનું બેકઅપ લો',
    },
    'dashboard.promo.newFeatureTitle': {
      'en': 'New Feature',
      'hi': 'नई सुविधा',
      'mr': 'नवीन वैशिष्ट्य',
      'gu': 'નવી સુવિધા',
    },
    'dashboard.promo.newFeatureSubtitle': {
      'en': 'Emergency SOS now supports quick location',
      'hi': 'आपातकालीन SOS अब तेज स्थान समर्थन करता है',
      'mr': 'आपत्कालीन SOS आता जलद स्थान समर्थन करतो',
      'gu': 'એમરજન્સી SOS હવે ઝડપી સ્થાન સપોર્ટ કરે છે',
    },
    'settings.linkSuccess': {
      'en': 'Profile linked successfully',
      'hi': 'प्रोफ़ाइल सफलतापूर्वक लिंक हो गई',
      'mr': 'प्रोफाइल यशस्वीपणे जोडले गेले',
      'gu': 'પ્રોફાઇલ સફળતાપૂર્વક જોડાઈ ગયું',
    },
    'settings.createSuccess': {
      'en': 'Profile created and linked successfully',
      'hi': 'प्रोफ़ाइल सफलतापूर्वक बनाई और लिंक की गई',
      'mr': 'प्रोफाइल तयार करून यशस्वीपणे जोडले गेले',
      'gu': 'પ્રોફાઇલ સફળતાપૂર્વક બનાવી અને જોડાઈ',
    },
    'settings.removeSuccess': {
      'en': '{name} removed successfully',
      'hi': '{name} सफलतापूर्वक हटाया गया',
      'mr': '{name} यशस्वीपणे काढले गेले',
      'gu': '{name} સફળતાપૂર્વક દૂર કરવામાં આવ્યું',
    },
    'settings.removeConfirm': {
      'en': 'Are you sure you want to remove {name} from your linked profiles?',
      'hi': 'क्या आप वाकई {name} को अपनी लिंक्ड प्रोफ़ाइल से हटाना चाहते हैं?',
      'mr':
          'आपण खात्रीने {name} ला आपल्या जोडलेल्या प्रोफाइलमधून काढू इच्छिता?',
      'gu': 'શું તમે ખરેખર {name} ને જોડાયેલી પ્રોફાઇલમાંથી દૂર કરવા માંગો છો?',
    },
    'settings.logout.confirm': {
      'en': 'Are you sure you want to logout?',
      'hi': 'क्या आप वाकई लॉगआउट करना चाहते हैं?',
      'mr': 'आपण खात्रीने लॉगआऊट करू इच्छिता?',
      'gu': 'શું તમે ખાતરીથી લૉગઆઉટ કરવા માંગો છો?',
    },
    'settings.logout.success': {
      'en': 'Logged out successfully',
      'hi': 'सफलतापूर्वक लॉगआउट हो गए',
      'mr': 'यशस्वीपणे लॉगआऊट झाले',
      'gu': 'સફળતાપૂર્વક લૉગઆઉટ થયું',
    },
    'settings.logout.failure': {
      'en': 'Logout failed: {error}',
      'hi': 'लॉगआउट विफल: {error}',
      'mr': 'लॉगआऊट अयशस्वी: {error}',
      'gu': 'લૉગઆઉટ નિષ્ફળ થયું: {error}',
    },
    'settings.switch.success': {
      'en': 'Switched to {name}',
      'hi': '{name} पर स्विच किया गया',
      'mr': '{name} वर स्विच केले',
      'gu': '{name} પર સ્વિચ કરવામાં આવ્યું',
    },
    'settings.switch.failure': {
      'en': 'Failed to switch profile',
      'hi': 'प्रोफ़ाइल बदलने में विफल',
      'mr': 'प्रोफाइल बदलण्यात अयशस्वी',
      'gu': 'પ્રોફાઇલ બદલી શકાઈ નથી',
    },
    'settings.switch.dialogTitle': {
      'en': 'Switch to {name}',
      'hi': '{name} पर स्विच करें',
      'mr': '{name} वर स्विच करा',
      'gu': '{name} પર સ્વિચ કરો',
    },
    'update.dialog.requiredTitle': {
      'en': 'Update Required',
      'hi': 'Update Required',
      'mr': 'Update Required',
      'gu': 'Update Required',
    },
    'update.dialog.availableTitle': {
      'en': 'Update Available',
      'hi': 'Update Available',
      'mr': 'Update Available',
      'gu': 'Update Available',
    },
    'update.dialog.current': {
      'en': 'Current',
      'hi': 'Current',
      'mr': 'Current',
      'gu': 'Current',
    },
    'update.dialog.latest': {
      'en': 'Latest',
      'hi': 'Latest',
      'mr': 'Latest',
      'gu': 'Latest',
    },
    'update.dialog.minimum': {
      'en': 'Minimum supported',
      'hi': 'Minimum supported',
      'mr': 'Minimum supported',
      'gu': 'Minimum supported',
    },
    'update.dialog.whatsNew': {
      'en': "What's new",
      'hi': "What's new",
      'mr': "What's new",
      'gu': "What's new",
    },
    'update.dialog.downloading': {
      'en': 'Downloading {progress}%',
      'hi': 'Downloading {progress}%',
      'mr': 'Downloading {progress}%',
      'gu': 'Downloading {progress}%',
    },
    'update.dialog.checksumVerified': {
      'en': 'Checksum verified',
      'hi': 'Checksum verified',
      'mr': 'Checksum verified',
      'gu': 'Checksum verified',
    },
    'update.action.updateNow': {
      'en': 'Update Now',
      'hi': 'Update Now',
      'mr': 'Update Now',
      'gu': 'Update Now',
    },
    'update.action.skip': {
      'en': 'Skip',
      'hi': 'Skip',
      'mr': 'Skip',
      'gu': 'Skip',
    },
    'about.title': {
      'en': 'About App',
      'hi': 'About App',
      'mr': 'About App',
      'gu': 'About App',
    },
    'about.checkLatest': {
      'en': 'Check Latest Update',
      'hi': 'Check Latest Update',
      'mr': 'Check Latest Update',
      'gu': 'Check Latest Update',
    },
    'about.upToDate': {
      'en': 'You are using the latest version.',
      'hi': 'You are using the latest version.',
      'mr': 'You are using the latest version.',
      'gu': 'You are using the latest version.',
    },
    'about.releaseNotes': {
      'en': 'Release Notes',
      'hi': 'Release Notes',
      'mr': 'Release Notes',
      'gu': 'Release Notes',
    },
    'about.pageSubtitle': {
      'en':
          'View the installed version, compare the latest release, and trigger in-app updates.',
      'hi':
          'View the installed version, compare the latest release, and trigger in-app updates.',
      'mr':
          'View the installed version, compare the latest release, and trigger in-app updates.',
      'gu':
          'View the installed version, compare the latest release, and trigger in-app updates.',
    },
    'about.identitySectionTitle': {
      'en': 'App Identity',
      'hi': 'App Identity',
      'mr': 'App Identity',
      'gu': 'App Identity',
    },
    'about.identitySectionSubtitle': {
      'en': 'Basic package and version metadata for this installation.',
      'hi': 'Basic package and version metadata for this installation.',
      'mr': 'Basic package and version metadata for this installation.',
      'gu': 'Basic package and version metadata for this installation.',
    },
    'about.field.appName': {
      'en': 'App Name',
      'hi': 'App Name',
      'mr': 'App Name',
      'gu': 'App Name',
    },
    'about.field.package': {
      'en': 'Package',
      'hi': 'Package',
      'mr': 'Package',
      'gu': 'Package',
    },
    'about.field.version': {
      'en': 'Version',
      'hi': 'Version',
      'mr': 'Version',
      'gu': 'Version',
    },
    'about.updatesSectionTitle': {
      'en': 'Updates',
      'hi': 'Updates',
      'mr': 'Updates',
      'gu': 'Updates',
    },
    'about.updatesSectionSubtitle': {
      'en':
          'Check the latest release, review notes, and install when available.',
      'hi':
          'Check the latest release, review notes, and install when available.',
      'mr':
          'Check the latest release, review notes, and install when available.',
      'gu':
          'Check the latest release, review notes, and install when available.',
    },
    'update.field.current': {
      'en': 'Current',
      'hi': 'Current',
      'mr': 'Current',
      'gu': 'Current',
    },
    'update.field.latest': {
      'en': 'Latest',
      'hi': 'Latest',
      'mr': 'Latest',
      'gu': 'Latest',
    },
    'update.field.minimumSupported': {
      'en': 'Minimum Supported',
      'hi': 'Minimum Supported',
      'mr': 'Minimum Supported',
      'gu': 'Minimum Supported',
    },
    'update.dialog.defaultNotes': {
      'en': 'Performance improvements and bug fixes.',
      'hi': 'Performance improvements and bug fixes.',
      'mr': 'Performance improvements and bug fixes.',
      'gu': 'Performance improvements and bug fixes.',
    },
  };

  static final Map<String, Map<String, String>> _autoTranslations = {
    'My Profile': {
      'hi': 'मेरा प्रोफ़ाइल',
      'mr': 'माझे प्रोफाइल',
      'gu': 'મારું પ્રોફાઇલ',
    },
    'Switch Profile': {
      'hi': 'प्रोफ़ाइल बदलें',
      'mr': 'प्रोफाइल बदला',
      'gu': 'પ્રોફાઇલ બદલો',
    },
    'Security': {
      'hi': 'सुरक्षा',
      'mr': 'सुरक्षा',
      'gu': 'સુરક્ષા',
    },
    'QR & Sharing': {
      'hi': 'क्यूआर और साझा करना',
      'mr': 'क्यूआर आणि शेअरिंग',
      'gu': 'ક્યુઆર અને શેરિંગ',
    },
    'Switch Themes': {
      'hi': 'थीम बदलें',
      'mr': 'थीम बदला',
      'gu': 'થીમ બદલો',
    },
    'Notifications': {
      'hi': 'सूचनाएँ',
      'mr': 'सूचना',
      'gu': 'સૂચનાઓ',
    },
    'Privacy & Terms': {
      'hi': 'गोपनीयता और नियम',
      'mr': 'गोपनीयता आणि अटी',
      'gu': 'ગોપનીયતા અને શરતો',
    },
    'Help & Support': {
      'hi': 'सहायता और समर्थन',
      'mr': 'मदत आणि समर्थन',
      'gu': 'મદદ અને ટેકનિકલ સહાય',
    },
    'Account': {
      'hi': 'खाता',
      'mr': 'खाते',
      'gu': 'એકાઉન્ટ',
    },
    'Patient': {
      'hi': 'रोगी',
      'mr': 'रुग्ण',
      'gu': 'દર્દી',
    },
    'Personal Details': {
      'hi': 'व्यक्तिगत विवरण',
      'mr': 'वैयक्तिक तपशील',
      'gu': 'વ્યક્તિગત વિગતો',
    },
    'View and edit your personal details': {
      'hi': 'अपने व्यक्तिगत विवरण देखें और संपादित करें',
      'mr': 'आपल्या वैयक्तिक तपशीलांचे दर्शन घ्या आणि संपादित करा',
      'gu': 'તમારી વ્યક્તિગત વિગતો જુઓ અને સંપાદિત કરો',
    },
    'Session Expiring': {
      'hi': 'सत्र समाप्त हो रहा है',
      'mr': 'सत्र समाप्त होत आहे',
      'gu': 'સત્ર સમાપ્ત થઈ રહ્યું છે',
    },
    'Get notified when your session with doctor is about to expire (last 30 seconds)':
        {
      'hi':
          'जब आपका डॉक्टर के साथ सत्र समाप्त होने वाला हो (आखिरी 30 सेकेंड) तब सूचनाएं प्राप्त करें',
      'mr':
          'तुमचे डॉक्टरांसोबतचे सत्र समाप्त होण्याच्या (शेवटच्या ३० सेकंदात) सूचना मिळवा',
      'gu':
          'જ્યારે તમારા ડૉક્ટર સાથેનું સત્ર સમાપ્ત થવા આવે (છેલ્લા 30 સેકંડ) ત્યારે સૂચનાઓ મેળવો',
    },
    'Reminders': {
      'hi': 'अनुस्मारक',
      'mr': 'आठवणी',
      'gu': 'રિમાઇન્ડર',
    },
    'Receive appointment reminders and other important notifications': {
      'hi': 'अपॉइंटमेंट अनुस्मारक और अन्य महत्वपूर्ण सूचनाएँ प्राप्त करें',
      'mr': 'अपॉइंटमेंटची आठवण आणि इतर महत्त्वाच्या सूचनांचा लाभ घ्या',
      'gu': 'અપૉઇન્ટમેન્ટ રિમાઇન્ડર અને અન્ય મહત્વપૂર્ણ સૂચનાઓ મેળવો',
    },
    'System': {
      'hi': 'सिस्टम',
      'mr': 'सिस्टम',
      'gu': 'સિસ્ટમ',
    },
    'Get system updates, advertisements, and instruction notifications': {
      'hi': 'सिस्टम अपडेट, विज्ञापन और निर्देश सूचनाएँ प्राप्त करें',
      'mr': 'सिस्टम अद्यतने, जाहिराती आणि सूचना नोटिफिकेशन्स मिळवा',
      'gu': 'સિસ્ટમ અપડેટ, જાહેરાતો અને સૂચના સંદેશાઓ મેળવો',
    },
    'Password': {
      'hi': 'पासवर्ड',
      'mr': 'पासवर्ड',
      'gu': 'પાસવર્ડ',
    },
    'Regenerate QR': {
      'hi': 'क्यूआर पुनः उत्पन्न करें',
      'mr': 'क्यूआर पुन्हा तयार करा',
      'gu': 'ક્યુઆર ફરીથી બનાવો',
    },
    'Sharing Controls': {
      'hi': 'शेयरिंग नियंत्रण',
      'mr': 'शेअरिंग नियंत्रणे',
      'gu': 'શેરિંગ નિયંત્રણો',
    },
    'Dark Mode': {
      'hi': 'डार्क मोड',
      'mr': 'डार्क मोड',
      'gu': 'ડાર્ક મોડ',
    },
    'Privacy Policy': {
      'hi': 'गोपनीयता नीति',
      'mr': 'गोपनीयता धोरण',
      'gu': 'ગોપનીયતા નીતિ',
    },
    'Terms of Service': {
      'hi': 'सेवा की शर्तें',
      'mr': 'सेवा अटी',
      'gu': 'સેવાની શરતો',
    },
    'FAQs': {
      'hi': 'अक्सर पूछे जाने वाले प्रश्न',
      'mr': 'नेहमी विचारले जाणारे प्रश्न',
      'gu': 'વારંવાર પૂછાતા પ્રશ્નો',
    },
    'Contact Support': {
      'hi': 'सहायता से संपर्क करें',
      'mr': 'सपोर्टशी संपर्क करा',
      'gu': 'સહાય માટે સંપર્ક કરો',
    },
    'Name': {
      'hi': 'नाम',
      'mr': 'नाव',
      'gu': 'નામ',
    },
    'Enter full name': {
      'hi': 'पूरा नाम दर्ज करें',
      'mr': 'पूर्ण नाव टाका',
      'gu': 'પૂર્ણ નામ દાખલ કરો',
    },
    'Email': {
      'hi': 'ईमेल',
      'mr': 'ईमेल',
      'gu': 'ઇમેઇલ',
    },
    'Enter email of existing profile': {
      'hi': 'मौजूदा प्रोफ़ाइल का ईमेल दर्ज करें',
      'mr': 'विद्यमान प्रोफाइलचा ईमेल टाका',
      'gu': 'હાજર પ્રોફાઇલનું ઇમેઇલ દાખલ કરો',
    },
    'Enter email address': {
      'hi': 'ईमेल पता दर्ज करें',
      'mr': 'ईमेल पत्ता टाका',
      'gu': 'ઇમેઇલ સરનામું દાખલ કરો',
    },
    'Mobile': {
      'hi': 'मोबाइल',
      'mr': 'मोबाइल',
      'gu': 'મોબાઇલ',
    },
    'Enter mobile number': {
      'hi': 'मोबाइल नंबर दर्ज करें',
      'mr': 'मोबाइल क्रमांक टाका',
      'gu': 'મોબાઇલ નંબર દાખલ કરો',
    },
    'Add Profile': {
      'hi': 'प्रोफ़ाइल जोड़ें',
      'mr': 'प्रोफाइल जोडा',
      'gu': 'પ્રોફાઇલ ઉમેરો',
    },
    'Language': {
      'hi': 'भाषा',
      'mr': 'भाषा',
      'gu': 'ભાષા',
    },
    'Link an existing or create new profile': {
      'hi': 'मौजूदा प्रोफ़ाइल जोड़ें या नया बनाएँ',
      'mr': 'विद्यमान प्रोफाइल जोडा किंवा नवीन तयार करा',
      'gu': 'હાલનું પ્રોફાઇલ જોડો અથવા નવું બનાવો',
    },
    'No linked profiles': {
      'hi': 'कोई लिंक्ड प्रोफ़ाइल नहीं',
      'mr': 'कोणतीही जोडलेली प्रोफाइल नाहीत',
      'gu': 'કોઈ જોડાયેલ પ્રોફાઇલ નથી',
    },
    'Add profiles to switch between them': {
      'hi': 'प्रोफ़ाइल जोड़ें और उनके बीच स्विच करें',
      'mr': 'प्रोफाइल जोडा आणि त्यांच्यात स्विच करा',
      'gu': 'પ્રોફાઇલ ઉમેરો અને તેમના વચ્ચે બદલાવ કરો',
    },
    'English': {
      'hi': 'अंग्रेज़ी',
      'mr': 'इंग्रजी',
      'gu': 'અંગ્રેજી',
    },
    'Hindi': {
      'hi': 'हिन्दी',
      'mr': 'हिंदी',
      'gu': 'હિન્દી',
    },
    'Marathi': {
      'hi': 'मराठी',
      'mr': 'मराठी',
      'gu': 'મરાઠી',
    },
    'Gujarati': {
      'hi': 'गुजराती',
      'mr': 'गुजराती',
      'gu': 'ગુજરાતી',
    },
    'Logout': {
      'hi': 'लॉगआउट',
      'mr': 'लॉगआऊट',
      'gu': 'લૉગઆઉટ',
    },
    'Unknown': {
      'hi': 'अज्ञात',
      'mr': 'अज्ञात',
      'gu': 'અજ્ઞાત',
    },
    'Sign out of your account': {
      'hi': 'अपने खाते से साइन आउट करें',
      'mr': 'आपल्या खात्यातून साइन आऊट करा',
      'gu': 'તમારા ખાતામાંથી સાઇન આઉટ કરો',
    },
    'Email/Password': {
      'hi': 'ईमेल/पासवर्ड',
      'mr': 'ईमेल/पासवर्ड',
      'gu': 'ઇમેઇલ/પાસવર્ડ',
    },
    'Link Existing Profile': {
      'hi': 'मौजूदा प्रोफ़ाइल लिंक करें',
      'mr': 'विद्यमान प्रोफाइल जोडा',
      'gu': 'હાલની પ્રોફાઇલ જોડો',
    },
    'Link an existing email/password account': {
      'hi': 'मौजूदा ईमेल/पासवर्ड खाता लिंक करें',
      'mr': 'विद्यमान ईमेल/पासवर्ड खाते जोडा',
      'gu': 'હાલનું ઇમેઇલ/પાસવર્ડ એકાઉન્ટ જોડો',
    },
    'Create New Profile': {
      'hi': 'नई प्रोफ़ाइल बनाएं',
      'mr': 'नवीन प्रोफाइल तयार करा',
      'gu': 'નવી પ્રોફાઇલ બનાવો',
    },
    'Create a new email/password profile': {
      'hi': 'नई ईमेल/पासवर्ड प्रोफ़ाइल बनाएं',
      'mr': 'नवीन ईमेल/पासवर्ड प्रोफाइल तयार करा',
      'gu': 'નવી ઇમેઇલ/પાસવર્ડ પ્રોફાઇલ બનાવો',
    },
    'Google Sign-In': {
      'hi': 'गूगल साइन-इन',
      'mr': 'गूगल साइन-इन',
      'gu': 'ગૂગલ સાઇન-ઇન',
    },
    'Link with Google': {
      'hi': 'गूगल से लिंक करें',
      'mr': 'गूगलसोबत जोडा',
      'gu': 'ગૂગલ સાથે લિંક કરો',
    },
    'Link an existing Google account': {
      'hi': 'मौजूदा गूगल खाता लिंक करें',
      'mr': 'विद्यमान गूगल खाते जोडा',
      'gu': 'હાલનું ગૂગલ એકાઉન્ટ જોડો',
    },
    'Create with Google': {
      'hi': 'गूगल के साथ बनाएँ',
      'mr': 'गूगलसह तयार करा',
      'gu': 'ગૂગલ સાથે બનાવો',
    },
    'Create a new Google profile': {
      'hi': 'नई गूगल प्रोफ़ाइल बनाएं',
      'mr': 'नवीन गूगल प्रोफाइल तयार करा',
      'gu': 'નવી ગૂગલ પ્રોફાઇલ બનાવો',
    },
    'Google profile linked successfully': {
      'hi': 'गूगल प्रोफ़ाइल सफलतापूर्वक लिंक हो गई',
      'mr': 'गूगल प्रोफाइल यशस्वीपणे जोडले गेले',
      'gu': 'ગૂગલ પ્રોફાઇલ સફળતાપૂર્વક જોડાઈ ગયું',
    },
    'Failed to link Google profile': {
      'hi': 'गूगल प्रोफ़ाइल लिंक नहीं हो सकी',
      'mr': 'गूगल प्रोफाइल जोडण्यात अयशस्वी',
      'gu': 'ગૂગલ પ્રોફાઇલ જોડાઈ શકી નથી',
    },
    'Google profile created and linked successfully': {
      'hi': 'गूगल प्रोफ़ाइल सफलतापूर्वक बनाई और लिंक की गई',
      'mr': 'गूगल प्रोफाइल तयार करून यशस्वीपणे जोडले गेले',
      'gu': 'ગૂગલ પ્રોફાઇલ સફળતાપૂર્વક બનાવી અને જોડાઈ',
    },
    'Failed to create Google profile': {
      'hi': 'गूगल प्रोफ़ाइल बनाई नहीं जा सकी',
      'mr': 'गूगल प्रोफाइल तयार करण्यात अयशस्वी',
      'gu': 'ગૂગલ પ્રોફાઇલ બનાવી શકાઈ નથી',
    },
    'Failed to remove profile': {
      'hi': 'प्रोफ़ाइल हटाने में विफल',
      'mr': 'प्रोफाइल काढण्यात अयशस्वी',
      'gu': 'પ્રોફાઇલ દૂર કરવામાં નિષ્ફળતા',
    },
    'Cancel': {
      'hi': 'रद्द करें',
      'mr': 'रद्द करा',
      'gu': 'રદ કરો',
    },
    'Link': {
      'hi': 'लिंक करें',
      'mr': 'लिंक करा',
      'gu': 'લિંક કરો',
    },
    'Create': {
      'hi': 'बनाएँ',
      'mr': 'तयार करा',
      'gu': 'બનાવો',
    },
    'Switch to this profile': {
      'hi': 'इस प्रोफ़ाइल पर स्विच करें',
      'mr': 'या प्रोफाइलवर स्विच करा',
      'gu': 'આ પ્રોફાઇલ પર સ્વિચ કરો',
    },
    'Remove profile': {
      'hi': 'प्रोफ़ाइल हटाएँ',
      'mr': 'प्रोफाइल काढा',
      'gu': 'પ્રોફાઇલ દૂર કરો',
    },
    'Remove Profile': {
      'hi': 'प्रोफ़ाइल हटाएँ',
      'mr': 'प्रोफाइल काढा',
      'gu': 'પ્રોફાઇલ દૂર કરો',
    },
    'Remove': {
      'hi': 'हटाएँ',
      'mr': 'काढा',
      'gu': 'દૂર કરો',
    },
    'Switch': {
      'hi': 'बदलें',
      'mr': 'बदला',
      'gu': 'બદલો',
    },
    'Enter password': {
      'hi': 'पासवर्ड दर्ज करें',
      'mr': 'पासवर्ड टाका',
      'gu': 'પાસવર્ડ દાખલ કરો',
    },
    'Enter password for {name}:': {
      'hi': '{name} के लिए पासवर्ड दर्ज करें:',
      'mr': '{name} साठी पासवर्ड टाका:',
      'gu': '{name} માટે પાસવર્ડ દાખલ કરો:',
    },
    'Medical Card': {
      'hi': 'चिकित्सा कार्ड',
      'mr': 'वैद्यकीय कार्ड',
      'gu': 'મેડિકલ કાર્ડ',
    },
    'View your permanent medical card QR code': {
      'hi': 'अपना स्थायी चिकित्सा कार्ड QR कोड देखें',
      'mr': 'तुमचा कायमस्वरूपी वैद्यकीय कार्ड QR कोड पहा',
      'gu': 'તમારો કાયમી મેડિકલ કાર્ડ QR કોડ જુઓ',
    },
    'My Medical Card QR Code': {
      'hi': 'मेरा चिकित्सा कार्ड QR कोड',
      'mr': 'माझा वैद्यकीय कार्ड QR कोड',
      'gu': 'મારો મેડિકલ કાર્ડ QR કોડ',
    },
    'Medical Card QR Code': {
      'hi': 'चिकित्सा कार्ड QR कोड',
      'mr': 'वैद्यकीय कार्ड QR कोड',
      'gu': 'મેડિકલ કાર્ડ QR કોડ',
    },
    'Scan to view medical card': {
      'hi': 'चिकित्सा कार्ड देखने के लिए स्कैन करें',
      'mr': 'वैद्यकीय कार्ड पाहण्यासाठी स्कॅन करा',
      'gu': 'મેડિકલ કાર્ડ જોવા માટે સ્કેન કરો',
    },
    'Share QR Code': {
      'hi': 'QR कोड साझा करें',
      'mr': 'QR कोड शेअर करा',
      'gu': 'QR કોડ શેર કરો',
    },
    'About Medical Card': {
      'hi': 'चिकित्सा कार्ड के बारे में',
      'mr': 'वैद्यकीय कार्ड बद्दल',
      'gu': 'મેડિકલ કાર્ડ વિશે',
    },
    'This QR code provides permanent access to your medical card. Anyone can scan it to view your essential medical information in case of emergency.':
        {
      'hi':
          'यह QR कोड आपके चिकित्सा कार्ड तक स्थायी पहुंच प्रदान करता है। कोई भी इसे स्कैन करके आपातकाल की स्थिति में आपकी आवश्यक चिकित्सा जानकारी देख सकता है।',
      'mr':
          'हा QR कोड तुमच्या वैद्यकीय कार्डला कायमस्वरूपी प्रवेश प्रदान करतो. कोणीही आपत्कालीन परिस्थितीत तुमची आवश्यक वैद्यकीय माहिती पाहण्यासाठी ते स्कॅन करू शकतो.',
      'gu':
          'આ QR કોડ તમારા મેડિકલ કાર્ડ સુધી કાયમી પ્રવેશ પ્રદાન કરે છે. કોઈપણ કટોકટીની સ્થિતિમાં તમારી આવશ્યક તબીબી માહિતી જોવા માટે તેને સ્કેન કરી શકે છે.',
    },
    'Failed to share QR code:': {
      'hi': 'QR कोड साझा करने में विफल:',
      'mr': 'QR कोड शेअर करण्यात अयशस्वी:',
      'gu': 'QR કોડ શેર કરવામાં નિષ્ફળ:',
    },
  };

  String t(String key) {
    final languageCode = locale.languageCode;
    final values = _keyedTranslations[key] ?? _autoTranslations[key];
    if (values == null) return key;
    return values[languageCode] ?? values['en'] ?? key;
  }

  String format(String key, Map<String, String> params) {
    var value = t(key);
    params.forEach((placeholder, replacement) {
      value = value.replaceAll('{$placeholder}', replacement);
    });
    return value;
  }

  String auto(String sourceText) {
    final normalized = sourceText.trim();
    final keyedValues = _keyedTranslations[normalized];
    if (keyedValues != null) {
      return keyedValues[locale.languageCode] ??
          keyedValues['en'] ??
          sourceText;
    }
    final map = _autoTranslations[normalized];
    if (map == null) return sourceText;
    return map[locale.languageCode] ?? sourceText;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .map((e) => e.languageCode)
      .contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final instance = AppLocalizations(locale);
    AppLocalizations._lastLoadedInstance = instance;
    return instance;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
