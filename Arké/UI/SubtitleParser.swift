//
//  SubtitleParser.swift
//  Arké
//
//  Created by Christoph on 01/20/26.
//

import Foundation

// MARK: - Subtitle Parser for VTT and SRT files

struct SubtitleParser {
    
    /// Parse WebVTT subtitle file
    /// Format:
    /// ```
    /// WEBVTT
    ///
    /// 00:00:00.000 --> 00:00:02.500
    /// Welcome to Arké
    ///
    /// 00:00:02.500 --> 00:00:05.000
    /// The future of secure digital assets
    /// ```
    static func parseVTT(from filename: String) -> [VideoSubtitle] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "vtt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("❌ Could not load VTT file: \(filename).vtt")
            return []
        }
        
        return parseVTT(content: content)
    }
    
    static func parseVTT(content: String) -> [VideoSubtitle] {
        var subtitles: [VideoSubtitle] = []
        let lines = content.components(separatedBy: .newlines)
        
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            // Look for timestamp line (contains "-->")
            if line.contains("-->") {
                let times = line.components(separatedBy: "-->").map { $0.trimmingCharacters(in: .whitespaces) }
                
                if times.count == 2,
                   let startTime = parseVTTTimestamp(times[0]),
                   let endTime = parseVTTTimestamp(times[1]) {
                    
                    // Collect subtitle text (may span multiple lines)
                    i += 1
                    var text = ""
                    while i < lines.count {
                        let textLine = lines[i].trimmingCharacters(in: .whitespaces)
                        if textLine.isEmpty {
                            break
                        }
                        if !text.isEmpty {
                            text += " "
                        }
                        text += textLine
                        i += 1
                    }
                    
                    if !text.isEmpty {
                        subtitles.append(VideoSubtitle(
                            startTime: startTime,
                            endTime: endTime,
                            text: text
                        ))
                    }
                }
            }
            i += 1
        }
        
        return subtitles
    }
    
    /// Parse SRT subtitle file
    /// Format:
    /// ```
    /// 1
    /// 00:00:00,000 --> 00:00:02,500
    /// Welcome to Arké
    ///
    /// 2
    /// 00:00:02,500 --> 00:00:05,000
    /// The future of secure digital assets
    /// ```
    static func parseSRT(from filename: String) -> [VideoSubtitle] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "srt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("❌ Could not load SRT file: \(filename).srt")
            return []
        }
        
        return parseSRT(content: content)
    }
    
    static func parseSRT(content: String) -> [VideoSubtitle] {
        var subtitles: [VideoSubtitle] = []
        let lines = content.components(separatedBy: .newlines)
        
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            // Look for timestamp line (contains "-->")
            if line.contains("-->") {
                let times = line.components(separatedBy: "-->").map { $0.trimmingCharacters(in: .whitespaces) }
                
                if times.count == 2,
                   let startTime = parseSRTTimestamp(times[0]),
                   let endTime = parseSRTTimestamp(times[1]) {
                    
                    // Collect subtitle text (may span multiple lines)
                    i += 1
                    var text = ""
                    while i < lines.count {
                        let textLine = lines[i].trimmingCharacters(in: .whitespaces)
                        if textLine.isEmpty {
                            break
                        }
                        if !text.isEmpty {
                            text += " "
                        }
                        text += textLine
                        i += 1
                    }
                    
                    if !text.isEmpty {
                        subtitles.append(VideoSubtitle(
                            startTime: startTime,
                            endTime: endTime,
                            text: text
                        ))
                    }
                }
            }
            i += 1
        }
        
        return subtitles
    }
    
    // MARK: - Private Helpers
    
    /// Parse VTT timestamp format: "00:00:02.500" or "02.500"
    private static func parseVTTTimestamp(_ timestamp: String) -> TimeInterval? {
        let components = timestamp.components(separatedBy: ":")
        
        var hours: Double = 0
        var minutes: Double = 0
        var seconds: Double = 0
        
        if components.count == 3 {
            // HH:MM:SS.mmm
            hours = Double(components[0]) ?? 0
            minutes = Double(components[1]) ?? 0
            seconds = Double(components[2].replacingOccurrences(of: ",", with: ".")) ?? 0
        } else if components.count == 2 {
            // MM:SS.mmm
            minutes = Double(components[0]) ?? 0
            seconds = Double(components[1].replacingOccurrences(of: ",", with: ".")) ?? 0
        } else if components.count == 1 {
            // SS.mmm
            seconds = Double(components[0].replacingOccurrences(of: ",", with: ".")) ?? 0
        } else {
            return nil
        }
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
    /// Parse SRT timestamp format: "00:00:02,500"
    private static func parseSRTTimestamp(_ timestamp: String) -> TimeInterval? {
        let components = timestamp.components(separatedBy: ":")
        
        guard components.count == 3 else { return nil }
        
        let hours = Double(components[0]) ?? 0
        let minutes = Double(components[1]) ?? 0
        let secondsWithMillis = components[2].replacingOccurrences(of: ",", with: ".")
        let seconds = Double(secondsWithMillis) ?? 0
        
        return hours * 3600 + minutes * 60 + seconds
    }
}

// MARK: - Example Usage

/*
 
 // In your IntroVideo array, you can now load subtitles from files:
 
 IntroVideo(
     title: "Welcome to Arké",
     thumbnailName: "video_thumb_1",
     videoAssetName: "coffee",
     subtitles: SubtitleParser.parseVTT(from: "coffee_subtitles")
 )
 
 // Or create them inline as you're currently doing:
 
 IntroVideo(
     title: "Welcome to Arké",
     thumbnailName: "video_thumb_1",
     videoAssetName: "coffee",
     subtitles: [
         VideoSubtitle(startTime: 0.0, endTime: 2.5, text: "Welcome to Arké"),
         VideoSubtitle(startTime: 2.5, endTime: 5.0, text: "The future of secure digital assets")
     ]
 )
 
 */
