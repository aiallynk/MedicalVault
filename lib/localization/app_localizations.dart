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
  };

  String t(String key) {
    final languageCode = locale.languageCode;
    final values = _keyedTranslations[key];
    if (values == null) return key;
    return values[languageCode] ?? values['en'] ?? key;
  }

  String format(String key, Map<String, String> params) {
    var value = t(key);
    params.forEach((placeholder, replacement) {
      value = value.replaceAll('{${placeholder}}', replacement);
    });
    return value;
  }

  String auto(String sourceText) {
    final normalized = sourceText.trim();
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
