import 'dart:convert';
import 'dart:io';

import 'package:campus_flutter/base/networking/apis/tumOnlineApi/tum_online_course_api.dart';
import 'package:campus_flutter/base/networking/base/rest_client.dart';
import 'package:campus_flutter/base/networking/cache/cache_entry.dart';
import 'package:campus_flutter/main.dart';
import 'package:campus_flutter/studiesComponent/model/lecture_details.dart';
import 'package:campus_flutter/studiesComponent/service/lecture_details_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

final fixture = File('test/fixtures/tumonline_course_details.json');

Map<String, dynamic> responseJson() =>
    jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('REST course details', () {
    test('maps the resource envelope to the lecture detail model', () {
      final details = LectureDetails.fromCourseJson(responseJson());
      expect(details.lvNumber, 950000001);
      expect(details.title, 'Algorithms & Data Structures');
      expect(details.stpSpSst, '4');
      expect(details.duration, '4');
      expect(details.eventTypeDefault, 'Vorlesung');
      expect(details.eventTypeTag, 'VO');
      expect(details.semester, 'Wintersemester 2026/27');
      expect(details.semesterID, '26W');
      expect(details.semesterYear, '2026/2027');
      expect(details.organisationNumber, 123);
      expect(details.organisation, 'School of Computation');
      expect(details.organisationTag, 'CIT');
      expect(details.speaker, 'Sam Lecturer, Alex Tutor');
      expect(details.courseContents, 'Trees\nGraphs\nSorting');
      expect(details.courseObjective, 'Design efficient algorithms');
      expect(details.requirements, 'Programming');
      expect(details.teachingMethod, 'Lectures and exercises');
      expect(details.examinationMode, 'Written exam');
      expect(details.signUpLV, 'Register online');
      expect(details.studienbehelfe, 'Algorithms textbook');
      expect(details.note, 'Bring a laptop');
      // No fabricated legacy URLs or meeting dates.
      expect(details.scheduledDatesURL, isNull);
      expect(details.firstScheduledDate, isNull);
    });

    test('allows absent optional metadata and descriptions', () {
      final details = LectureDetails.fromCourseJson({
        'resource': [
          {
            'content': {
              'cpCourseDetailDto': {
                'cpCourseDto': {
                  'id': 950000002,
                  'courseTitle': {'value': 'Minimal course'},
                },
              },
            },
          },
        ],
      });
      expect(details.title, 'Minimal course');
      expect(details.speaker, isNull);
      expect(details.courseContents, isNull);
      expect(details.stpSpSst, isEmpty);
    });

    test('ignores untranslated empty descriptions and derives summer year', () {
      final json = responseJson();
      final detail = json['resource'][1]['content']['cpCourseDetailDto'];
      detail['cpCourseDescriptionDto']['courseContent'] = {
        'translations': {
          'translation': [
            {'lang': 'en'},
          ],
        },
      };
      detail['cpCourseDto']['semesterDto']['semesterType'] = 'S';
      detail['cpCourseDto']['semesterDto']['startOfAcademicSemester']['value'] =
          '2026-04-01';
      final details = LectureDetails.fromCourseJson(json);
      expect(details.courseContents, isNull);
      expect(details.semesterYear, '2025/2026');
    });

    test('rejects missing detail resources and missing titles', () {
      expect(
        () => LectureDetails.fromCourseJson({'resource': []}),
        throwsFormatException,
      );
      final json = responseJson();
      json['resource'][1]['content']['cpCourseDetailDto']['cpCourseDto'].remove(
        'courseTitle',
      );
      expect(() => LectureDetails.fromCourseJson(json), throwsFormatException);
    });

    test('rejects invalid IDs before making an HTTP request', () {
      for (final id in ['', 'not-a-course', '123/other', '123?extra=true']) {
        expect(() => TumOnlineCourseApi(id), throwsFormatException);
      }
    });
  });

  group('LectureDetailsService REST integration', () {
    late CacheDatabase database;
    late RestClient client;
    late List<RequestOptions> requests;

    setUp(() {
      database = CacheDatabase();
      client = RestClient(database);
      requests = [];
      // Resolve requests before transport/cache: no network or platform storage.
      client.dio.interceptors
        ..clear()
        ..add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              requests.add(request);
              handler.resolve(
                Response<String>(
                  requestOptions: request,
                  statusCode: 200,
                  data: fixture.readAsStringSync(),
                  extra: {'saved': DateTime(2026, 10, 20)},
                ),
              );
            },
          ),
        );
      getIt.registerSingleton<RestClient>(client);
    });

    tearDown(() async {
      getIt.unregister<RestClient>();
      client.dio.close();
      await database.close();
    });

    test('loads public JSON details and preserves forced refresh', () async {
      for (final refresh in [false, true]) {
        final result = await LectureDetailsService.fetchLectureDetails(
          '950000001',
          refresh,
        );
        expect(result.$1, DateTime(2026, 10, 20));
        expect(result.$2.title, 'Algorithms & Data Structures');
        final request = requests.last;
        expect(
          request.uri.path,
          '/tumonline/ee/rest/slc.tm.cp/student/courses/950000001',
        );
        expect(request.uri.scheme, 'https');
        expect(request.uri.host, 'campus.tum.de');
        expect(request.headers['Accept'], 'application/json');
        expect(request.uri.queryParameters.containsKey('pToken'), isFalse);
        expect(request.extra['forcedRefresh'], refresh ? 'true' : isNull);
      }
    });
  });
}
