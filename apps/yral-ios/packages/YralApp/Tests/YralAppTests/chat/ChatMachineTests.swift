import Foundation
import Testing

@testable import YralApp

struct ChatListMachineTests {
  private func conversation(_ id: String) -> ChatConversation {
    ChatConversation(
      id: id, influencerID: id, influencerName: id, influencerDisplayName: id)
  }

  @Test
  func loadThenPaginate() {
    var state = ChatListMachine.State()
    state = ChatListMachine.transition(state, .load)
    #expect(state.isLoading)
    let page = (0..<ChatListMachine.pageSize).map { conversation("c\($0)") }
    state = ChatListMachine.transition(state, .loaded(page))
    #expect(state.conversations.count == ChatListMachine.pageSize)
    #expect(!state.isExhausted)

    state = ChatListMachine.transition(state, .loadMore)
    #expect(state.isLoadingMore)
    let next = (0..<ChatListMachine.pageSize).map { conversation("d\($0)") }
    state = ChatListMachine.transition(state, .moreLoaded([page[0]] + next))
    #expect(state.conversations.count == ChatListMachine.pageSize * 2)
    #expect(Set(state.conversations.map(\.id)).count == state.conversations.count)
  }

  @Test
  func shortPageIsExhaustedAndEmptyState() {
    var state = ChatListMachine.State()
    state = ChatListMachine.transition(state, .load)
    state = ChatListMachine.transition(state, .loaded([conversation("only")]))
    #expect(state.isExhausted)
    #expect(ChatListMachine.transition(state, .loadMore) == state)

    var empty = ChatListMachine.State()
    empty = ChatListMachine.transition(empty, .load)
    empty = ChatListMachine.transition(empty, .loaded([]))
    #expect(empty.isEmpty)
  }

  @Test
  func refreshReplacesAndFailurePreservesContent() {
    var state = ChatListMachine.State(
      conversations: [conversation("old")], nextOffset: 1, isExhausted: true)
    state = ChatListMachine.transition(state, .refresh)
    #expect(state.isRefreshing)
    state = ChatListMachine.transition(state, .refreshFailed("HTTP 503"))
    #expect(state.conversations.map(\.id) == ["old"])
    #expect(state.error == "HTTP 503")

    state = ChatListMachine.transition(state, .refresh)
    state = ChatListMachine.transition(state, .refreshLoaded([conversation("new")]))
    #expect(state.conversations.map(\.id) == ["new"])
    #expect(state.error == nil)
  }
}

struct ChatConversationMachineTests {
  private let conversation = ChatConversation(
    id: "c1", influencerID: "i1", influencerName: "aura", influencerDisplayName: "Aura")

  @Test
  func loadThenSendProducesOptimisticAndReply() {
    var state = ChatConversationMachine.State.loading(conversation)
    state = ChatConversationMachine.transition(
      state, .loaded([ChatMessage(id: "m1", role: "assistant", content: "Hi")]))
    #expect(state.messages.count == 1)
    #expect(state.conversation == conversation)

    state = ChatConversationMachine.transition(state, .send("Hello"))
    #expect(state.isSending)
    #expect(state.messages.last?.isFromUser == true)
    #expect(state.messages.count == 2)

    state = ChatConversationMachine.transition(
      state, .sent(ChatMessage(id: "m2", role: "assistant", content: "Hey!")))
    #expect(!state.isSending)
    #expect(state.messages.count == 3)
    #expect(state.messages.last?.content == "Hey!")
  }

  @Test
  func emptySendIsIgnored() {
    var state = ChatConversationMachine.State.loading(conversation)
    state = ChatConversationMachine.transition(state, .loaded([]))
    let blank = ChatConversationMachine.transition(state, .send("   "))
    #expect(blank == state)
  }

  @Test
  func sendFailureKeepsMessagesAndSurfacesError() {
    var state = ChatConversationMachine.State.loading(conversation)
    state = ChatConversationMachine.transition(
      state, .loaded([ChatMessage(id: "m1", role: "assistant", content: "Hi")]))
    state = ChatConversationMachine.transition(state, .send("Hello"))
    state = ChatConversationMachine.transition(state, .sendFailed("HTTP 500"))
    #expect(!state.isSending)
    #expect(state.error == "HTTP 500")
    #expect(state.messages.count == 2)
  }
}
