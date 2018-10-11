# frozen_string_literal: true

class CommentViewers
  attr_reader :comment, :owner, :current_user, :commentable_viewers

  def self.viewers(comment, current_user)
    new(comment, current_user).viewers
  end

  def self.viewable(comment, current_user)
    new(comment, current_user).viewable
  end

  def self.deletable(comment, current_user)
    new(comment, current_user).deletable
  end

  def initialize(comment, current_user)
    commentable = get_commentable(comment)
    @comment = comment
    @owner = commentable[:user_id] && User.find(commentable[:user_id])
    @commentable_viewers = commentable[:viewers] ||
                           commentable&.members&.pluck(:id)
    @current_user = current_user
  end

  def viewers
    return unless show_viewers?

    I18n.t('shared.comments.visible_only_between_you_and',
           name: other_person.name)
  end

  def viewable
    viewable?
  end

  def deletable
    current_user_comment? || commentable_owner?
  end

  private

  def show_viewers?
    @comment.visibility == 'private' && viewable?
  end

  def other_person
    if commentable_owner?
      if (viewer = User.where(id: @comment.viewers[0]).first)
        # you are logged in as owner, you made the comment,
        # and it is visible to a viewer
        viewer
      else
        # you are logged in as owner, and comment was made by somebody else
        User.find(@comment.comment_by)
      end
    else
      # you are logged in as comment maker, and it is visible to you and owner
      @owner
    end
  end

  def commentable_owner?
    if @comment.commentable_type == 'meeting'
      return MeetingMember.where(meeting_id: @comment.commentable_id,
                                 leader: true,
                                 user_id: current_user.id).exists?
    end
    @owner.id == @current_user.id
  end

  def current_user_comment?
    @comment.comment_by == @current_user.id
  end

  def comment_viewer?
    @comment.viewers.present? && @comment.viewers.include?(@current_user.id)
  end

  def commentable_viewer?
    @comment.visibility == 'all' &&
      @commentable_viewers.include?(@current_user.id)
  end

  def viewer?
    comment_viewer? || commentable_viewer?
  end

  def viewable?
    current_user_comment? || commentable_owner? ||
      viewer?
  end

  def get_commentable(comment)
    model = comment.commentable_type.classify.constantize
    model.find(comment.commentable_id)
  end
end
