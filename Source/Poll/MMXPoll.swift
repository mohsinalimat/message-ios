/*
 * Copyright (c) 2015 Magnet Systems, Inc.
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you
 * may not use this file except in compliance with the License. You
 * may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

import MagnetMaxCore

enum MMXPollErrorType : ErrorType {
    case IdEmpty
    case NameEmpty
    case OptionsEmpty
    case QuestionEmpty
}

@objc public class MMXPoll: NSObject {
    
    //MARK: Public Properties
    
    public private(set) var allowsMultipleChoice = false
    
    public private(set) var channel : MMXChannel?
    
    public let endDate: NSDate?
    
    public var extras : [String:String]?
    
    public let hideResultsFromOthers: Bool
    
    public private(set) var isPublished = false
    
    public private(set) var myVotes: [MMXPollOption]?
    
    public let name : String
    
    public let options: [MMXPollOption]
    
    public private(set) var ownerId : String?
    
    public private(set) var pollID: String?
    
    public let question: String
    
    //MARK: Private Properties
    
    private var underlyingSurvey : MMXSurvey?
    
    //MARK: Init
    
    public convenience init(name: String, question: String, options: [String], hideResultsFromOthers: Bool, endDate: NSDate? = nil, extras: [String:String]? = nil, allowsMultipleChoice: Bool = false) {
        
        var opts = [MMXPollOption]()
        for option in options {
            let mmxOption = MMXPollOption(pollID: "", optionID: "", text: option, count: 0)
            opts.append(mmxOption)
        }
        self.init(name : name, question: question, mmxPollOptions: opts, hideResultsFromOthers: hideResultsFromOthers, endDate: endDate, extras: extras, allowsMultipleChoice: allowsMultipleChoice)
    }
    
    //MARK: Creation
    
    public static func createPoll(name : String, question: String, options: [String], hideResultsFromOthers: Bool, endDate: NSDate? = nil, extras : [String:String]? = nil, allowsMultipleChoice : Bool = false) -> MMXPoll {
        return MMXPoll(name: name, question: question, options: options, hideResultsFromOthers: hideResultsFromOthers, endDate: endDate, extras: extras, allowsMultipleChoice: allowsMultipleChoice)
    }
    
    public static func createPoll(name : String, question: String, options: [String], hideResultsFromOthers: Bool, endDate: NSDate? = nil, extras : [String:String]? = nil) -> MMXPoll {
        return MMXPoll(name: name, question: question, options: options, hideResultsFromOthers: hideResultsFromOthers, endDate: endDate, extras: extras)
    }
    
    public static func createPoll(name : String, question: String, options: [String], hideResultsFromOthers: Bool, endDate: NSDate? = nil) -> MMXPoll {
        return MMXPoll(name: name, question: question, options: options, hideResultsFromOthers: hideResultsFromOthers, endDate: endDate)
    }
    
    public static func createPoll(name : String, question: String, options: [String], hideResultsFromOthers: Bool) -> MMXPoll {
        return MMXPoll(name: name, question: question, options: options, hideResultsFromOthers: hideResultsFromOthers)
    }
    
    //MARK: Private Init
    
    private init(name : String, question: String, mmxPollOptions options: [MMXPollOption], hideResultsFromOthers: Bool, endDate: NSDate?, extras: [String:String]?, allowsMultipleChoice: Bool) {
        self.question = question
        self.options = options
        self.name = name
        self.hideResultsFromOthers = hideResultsFromOthers
        self.endDate = endDate
        self.ownerId = MMUser.currentUser()?.userID
        self.extras = extras
        self.allowsMultipleChoice = allowsMultipleChoice
    }
    
    //MARK: Public Methods
    
    public func choose(option: MMXPollOption, success: (Void -> Void)?, failure: ((error: NSError) -> Void)?) {
        choose(options: [option], success: success, failure: failure)
    }
    
    public func choose(options option: [MMXPollOption], success: (Void -> Void)?, failure: ((error: NSError) -> Void)?) {
        
        guard let channel = self.channel else {
            assert(false, "Poll not related to a channel, please submit poll first.")
            
            return
        }
        
        guard options.count <= 1 || (options.count > 1 && self.allowsMultipleChoice) else {
            assert(false, "Only one option is allowed")
            
            return
        }
        
        var answers = [MMXSurveyAnswer]()
        
        for option in options {
            let answer = MMXSurveyAnswer()
            answer.selectedOptionId = option.optionID
            answer.text = option.text
            answer.questionId = self.underlyingSurvey?.surveyDefinition.questions.first?.questionId
            answers.append(answer)
        }
        
        let surveyAnswerRequest = MMXSurveyAnswerRequest()
        surveyAnswerRequest.answers = answers
        let call = MMXSurveyService().submitSurveyAnswers(self.pollID, body: surveyAnswerRequest, success: {
            let msg = MMXMessage(toChannel: channel, messageContent: [:])
            let result = MMXPollAnswer()
            result.result = option
            msg.payload = result;
            msg.sendWithSuccess({ users in
                success?()
                }, failure: { error in
                    failure?(error: error)
            })
            }, failure: { error in
                failure?(error: error)
        })
        call.executeInBackground(nil)
    }
    
    public func mmxPayload() -> MMXPollIdentifier? {
        return self.pollID != nil ? MMXPollIdentifier(self.pollID!) : nil
    }
    
    //MARK: Public Static Methods
    //MARK: Publish
    public func publish(channel channel: MMXChannel,success: ((MMXPoll) -> Void)?, failure: ((error: NSError) -> Void)?) {
        let msg = MMXMessage(toChannel: channel, messageContent: [:])
        publish(message: msg, success: success, failure: failure)
    }
    
    private func publish(message message: MMXMessage, success: ((MMXPoll) -> Void)?, failure: ((error: NSError) -> Void)?) {
        guard let channel = message.channel as MMXChannel? else {
            assert(false, "Channel must be set on message for poll")
            return
        }
        
        createPoll(channel, success: {
            message.payload = self.mmxPayload();
            message.sendWithSuccess({ users in
                self.isPublished = true
                ({ [weak self] in
                    if let weakSelf = self {
                        success?(weakSelf)
                    }
                    })()
                }, failure: { error in
                    failure?(error: error)
            })
            }, failure: { error in
                failure?(error: error)
        })
    }
    
    //MARK: Poll retrieval
    
    static public func pollFromMMXPayload(payload : MMXPayload, success: ((MMXPoll) -> Void), failure: ((error: NSError) -> Void)?) {
        if let pollIdentifier = payload as? MMXPollIdentifier {
            self.pollWithID(pollIdentifier.pollID, success: success, failure: failure)
        } else {
            let error = MMXClient.errorWithTitle("Poll", message: "Incompatible Object Type", code: 500)
            failure?(error : error)
        }
    }
    
    static public func pollWithID(pollID: String, success: ((MMXPoll) -> Void), failure: ((error: NSError) -> Void)?) {
        let service = MMXSurveyService()
        let call = service.getSurvey(pollID, success: {[weak service] survey in
            let call = service?.getResults(survey.surveyId, success: { surveyResults in
                let isPublic = !survey.surveyDefinition.notificationChannelId.containsString("#")
                MMXChannel.channelForName(survey.surveyDefinition.notificationChannelId, isPublic: isPublic, success: { channel in
                    do {
                        let poll = try self.pollFromSurveyResults(surveyResults, channel: channel)
                        success(poll)
                    } catch {
                        let error = MMXClient.errorWithTitle("Poll", message: "Error Parsing Poll", code: 400)
                        failure?(error : error)
                    }
                    }, failure: { error in
                        failure?(error : error)
                })
                }, failure: { error in
                    failure?(error : error)
            })
            call?.executeInBackground(nil)
            }, failure: { error in
                failure?(error : error)
        })
        call.executeInBackground(nil)
    }
    
    //MARK Private Static Methods
    
    private func createPoll(channel: MMXChannel, success: (() -> Void), failure: ((error: NSError) -> Void)) {
        
        guard let user = MMUser.currentUser() else  {
            let error = MMXClient.errorWithTitle("Login", message: "Must be logged in to use this API", code: 401)
            failure(error: error)
            return
        }
        
        let survey = MMXPoll.generateSurvey(channel: channel, owner: user, name: self.name, question: self.question, options: self.options, hideResultsFromOthers: self.hideResultsFromOthers, endDate: self.endDate, extras: self.extras, allowsMultipleChoice: self.allowsMultipleChoice)
        let call = MMXSurveyService().createSurvey(survey, success: { survey in
            let error = MMXClient.errorWithTitle("Poll", message: "Error Parsing Poll", code: 400)
            
            guard survey.surveyId != nil else {
                failure(error: error)
                return
            }
            
            self.pollID = survey.surveyId
            success()
            }, failure: { error in
                failure(error: error)
        })
        call.executeInBackground(nil)
    }
    
    private static func generateSurvey(channel channel: MMXChannel, owner: MMUser,name: String, question: String,  options: [MMXPollOption], hideResultsFromOthers: Bool, endDate: NSDate?, extras: [String : String]?, allowsMultipleChoice: Bool) -> MMXSurvey {
        let survey = MMXSurvey()
        survey.owners = [owner.userID]
        survey.name = name
        survey.metaData = extras
        let surveyDefinition = MMXSurveyDefinition()
        surveyDefinition.startDate = NSDate()
        surveyDefinition.endDate = endDate
        surveyDefinition.type = .POLL
        surveyDefinition.resultAccessModel = hideResultsFromOthers ? .PRIVATE : .PUBLIC
        surveyDefinition.participantModel = .PUBLIC
        survey.surveyDefinition = surveyDefinition
        let surveyQuestion = MMXSurveyQuestion()
        surveyQuestion.text = question
        surveyDefinition.notificationChannelId = channel.channelID
        var index = 0
        let surveyOptions : [MMXSurveyOption] = options.map({
            let option = MMXSurveyOption()
            option.displayOder = Int32(index)
            index += 1
            option.value = $0.text
            option.metaData = $0.extras
            
            return option
        })
        
        surveyQuestion.choices = surveyOptions
        surveyQuestion.displayOrder = 0
        surveyQuestion.type = allowsMultipleChoice ? .MULTI_CHOICE : .SINGLE_CHOICE
        surveyDefinition.questions = [surveyQuestion]
        
        return survey
    }
    
    private static func pollFromSurveyResults(results : MMXSurveyResults, channel : MMXChannel) throws -> MMXPoll {
        let survey = results.survey
        guard let sid = survey.surveyId else {
            throw MMXPollErrorType.IdEmpty
        }
        
        guard let name = survey.name else {
            throw MMXPollErrorType.NameEmpty
        }
        
        guard let question = survey.surveyDefinition.questions.first else {
            throw MMXPollErrorType.QuestionEmpty
        }
        
        guard let options = survey.surveyDefinition.questions.first?.choices else {
            throw MMXPollErrorType.OptionsEmpty
        }
        
        let hidesResults = survey.surveyDefinition.resultAccessModel == .PRIVATE
        let endDate = survey.surveyDefinition.endDate
        
        var choiceMap = [String : MMXSurveyChoiceResult]()
        for choiceResult in results.summary {
            choiceMap[choiceResult.selectedChoiceId] = choiceResult
        }
        
        var pollOptions: [MMXPollOption] = []
        var myAnswers : [MMXPollOption] = []
        for option in options {
            let count : Int64? = choiceMap[option.optionId] != nil ? choiceMap[option.optionId]!.count : nil
            let pollOption = MMXPollOption(pollID: survey.surveyId, optionID: option.optionId, text: option.value, count: count)
            pollOption.extras = option.metaData
            if results.myAnswers.map({$0.selectedOptionId}).contains(option.optionId) {
                myAnswers.append(pollOption)
            }
            pollOptions.append(pollOption)
        }
        
        let poll = MMXPoll.init(name: name, question: question.text, mmxPollOptions: pollOptions, hideResultsFromOthers: hidesResults, endDate: endDate, extras: survey.metaData, allowsMultipleChoice: question.type == .MULTI_CHOICE)
        poll.underlyingSurvey = survey
        poll.myVotes = myAnswers
        poll.ownerId = survey.owners.first
        poll.pollID = sid
        poll.channel = channel
        poll.isPublished = true
        
        return poll
    }
}

// MARK: MMXPoll Equality

extension MMXPoll {
    
    override public var hash: Int {
        return pollID?.hashValue ?? 0
    }
    
    override public func isEqual(object: AnyObject?) -> Bool {
        if let rhs = object as? MMXPoll {
            return pollID == rhs.pollID
        }
        
        return false
        
    }
}