import 'package:campus_flutter/base/networking/apis/tumOnlineApi/tum_online_course_api.dart';
import 'package:campus_flutter/base/networking/base/rest_client.dart';
import 'package:campus_flutter/main.dart';
import 'package:campus_flutter/studiesComponent/model/lecture_details.dart';

class LectureDetailsService {
  static Future<(DateTime?, LectureDetails)> fetchLectureDetails(
    String lvNumber,
    bool forcedRefresh,
  ) async {
    RestClient restClient = getIt<RestClient>();
    final response = await restClient.get<LectureDetails, TumOnlineCourseApi>(
      TumOnlineCourseApi(lvNumber),
      LectureDetails.fromCourseJson,
      forcedRefresh,
    );

    return (response.saved, response.data);
  }
}
