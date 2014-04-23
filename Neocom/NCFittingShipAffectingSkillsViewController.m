//
//  NCFittingShipAffectingSkillsViewController.m
//  Neocom
//
//  Created by Артем Шиманский on 10.02.14.
//  Copyright (c) 2014 Artem Shimanski. All rights reserved.
//

#import "NCFittingShipAffectingSkillsViewController.h"
#import "NSArray+Neocom.h"
#import "NCFittingCharacterEditorCell.h"
#import "UIActionSheet+Block.h"
#import "NCStorage.h"
#import "NCDatabaseTypeInfoViewController.h"

@interface NCFittingShipAffectingSkillsViewController ()
@property (nonatomic, strong) NSArray* sections;
@property (nonatomic, strong) NSDictionary* skills;

@end

@implementation NCFittingShipAffectingSkillsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	self.refreshControl = nil;
	self.title = self.character.name;
	
	NSMutableDictionary* skills = [NSMutableDictionary new];
	NSMutableArray* sections = [NSMutableArray new];
	[[self taskManager] addTaskWithIndentifier:NCTaskManagerIdentifierAuto
										 title:NCTaskManagerDefaultTitle
										 block:^(NCTask *task) {
											 [[EVEDBDatabase sharedDatabase] execSQLRequest:@"SELECT a.* FROM invTypes as a, invGroups as b where a.groupID=b.groupID and b.categoryID=16 and a.published = 1"
																				resultBlock:^(sqlite3_stmt *stmt, BOOL *needsMore) {
																					if ([task isCancelled])
																						*needsMore = NO;
																					NCSkillData* skillData = [[NCSkillData alloc] initWithStatement:stmt];
																					skillData.trainedLevel = -1;
																					skills[@(skillData.typeID)] = skillData;
																				}];

											 NSMutableDictionary* visibleSkills = [NSMutableDictionary new];
											 for (NSNumber* typeID in self.affectingSkillsTypeIDs) {
												 visibleSkills[typeID] = skills[typeID];
											 }
											 
											 for (NSArray* array in [[[visibleSkills allValues] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"typeName" ascending:YES]]] arrayGroupedByKey:@"groupID"]) {
												 NSString* title = [[array[0] group] groupName];
												 [sections addObject:@{@"title": title, @"rows": array, @"sectionID": @([array[0] groupID])}];
											 }
											 
											 [self.character.skills enumerateKeysAndObjectsUsingBlock:^(NSNumber* typeID, NSNumber* level, BOOL *stop) {
												 NCSkillData* skillData = skills[typeID];
												 skillData.currentLevel = [level intValue];
											 }];
											 [sections sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES]]];
											 
										 }
							 completionHandler:^(NCTask *task) {
								 self.skills = skills;
								 self.sections = sections;
								 [self update];
							 }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	if (self.modified) {
		NSMutableDictionary* skills = [NSMutableDictionary new];
		[self.skills enumerateKeysAndObjectsUsingBlock:^(NSNumber* typeID, NCSkillData* skillData, BOOL *stop) {
			skills[typeID] = @(skillData.currentLevel);
		}];
		self.character.skills = skills;
		if (!self.character.managedObjectContext) {
			NCStorage* storage = [NCStorage sharedStorage];
			[storage.managedObjectContext insertObject:self.character];
			[storage saveContext];
		}
	}
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if ([segue.identifier isEqualToString:@"NCDatabaseTypeInfoViewController"]) {
		NCDatabaseTypeInfoViewController* controller;
		if ([segue.destinationViewController isKindOfClass:[UINavigationController class]])
			controller = [segue.destinationViewController viewControllers][0];
		else
			controller = segue.destinationViewController;
		
		controller.type = [sender skillData];
	}
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [self.sections[section][@"rows"] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *CellIdentifier = @"Cell";
	NCFittingCharacterEditorCell* cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	NCSkillData* skill = self.sections[indexPath.section][@"rows"][indexPath.row];
	
	cell.skillNameLabel.text = skill.typeName;
	cell.skillLevelLabel.text = [NSString stringWithFormat:@"%d", skill.currentLevel];
	cell.skillData = skill;
	return cell;
}

- (NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return self.sections[section][@"title"];
}

#pragma mark - Table view delegate

- (CGFloat) tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 41;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
		return [self tableView:tableView estimatedHeightForRowAtIndexPath:indexPath];
	
	UITableViewCell* cell = [self tableView:tableView cellForRowAtIndexPath:indexPath];
	cell.bounds = CGRectMake(0, 0, CGRectGetWidth(tableView.bounds), CGRectGetHeight(cell.bounds));
	[cell setNeedsLayout];
	[cell layoutIfNeeded];
	return [cell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height + 1.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NCSkillData* skill = self.sections[indexPath.section][@"rows"][indexPath.row];
	UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
	NSMutableArray* buttons = [NSMutableArray new];
	for (int32_t i = 0; i <=5; i++)
		[buttons addObject:[NSString stringWithFormat:NSLocalizedString(@"Level %d", nil), i]];
	[[UIActionSheet actionSheetWithStyle:UIActionSheetStyleBlackTranslucent
								   title:nil
					   cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
				  destructiveButtonTitle:nil
					   otherButtonTitles:buttons
						 completionBlock:^(UIActionSheet *actionSheet, NSInteger selectedButtonIndex) {
							 if (selectedButtonIndex != actionSheet.cancelButtonIndex) {
								 skill.currentLevel = (int32_t) selectedButtonIndex;
								 [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
								 self.modified = YES;
							 }
						 }
							 cancelBlock:^{
								 
							 }] showFromRect:cell.bounds inView:cell animated:YES];
}


#pragma mark - NCTableViewController

- (NSString*) recordID {
	return nil;
}

- (id) identifierForSection:(NSInteger)section {
	return self.sections[section][@"sectionID"];
}

@end
