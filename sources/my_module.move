module my_first_package::my_module {
//a web3 app for marketplace to buying and selling ideas as asset
 
    use std::option::{Self, Option};
    use std::string::{Self, String};

    use sui::transfer;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::url::{Self, Url};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::object_table::{Self, ObjectTable};
    use sui::event;

    const NOT_THE_OWNER: u64 = 0;
    const INSUFFICIENT_FUNDS: u64 = 1;
    const MIN_CARD_COST: u64 = 1;
    const Tradable_Content: u64 = 0; //check is item tradable

    struct Idea has key, store {
        id: UID,
        name: String,
        owner: address,
        author: String,
        img_url: Url,
        description: Option<String>,
        years_of_invention: u8,
        technologies: String,
        portfolio: String,
        contact: String,
        open_to_sale: bool,
    }

    struct Ideas has key {
        id: UID,
        owner: address,
        counter: u64,
        cards: ObjectTable<u64, Idea>,
    }
    struct CardCreated has copy, drop {
        id: ID,
        name: String,
        owner: address,
        author: String,
        contact: String,
    }


    struct DescriptionUpdated has copy, drop {
        name: String,
        owner: address,
        new_description: String
    }


    fun init(ctx: &mut TxContext) {
        transfer::share_object(
            Ideas {
                id: object::new(ctx),
                owner: tx_context::sender(ctx),
                counter: 0,
                cards: object_table::new(ctx),
            }
        );
    }

   
    public entry fun create_card(
        name: vector<u8>,
        author: vector<u8>,
        img_url: vector<u8>,
        years_of_invention: u8,
        technologies: vector<u8>,
        portfolio: vector<u8>,
        contact: vector<u8>,
        payment: Coin<SUI>,
        ideas: &mut Ideas,
        ctx: &mut TxContext
    ) {
        let value = coin::value(&payment); 
        assert!(value == MIN_CARD_COST, INSUFFICIENT_FUNDS); 
        transfer::public_transfer(payment, ideas.owner); 

       
        ideas.counter = ideas.counter + 1;

       
        let id = object::new(ctx);

        
        event::emit(
            CardCreated { 
                id: object::uid_to_inner(&id), 
                name: string::utf8(name), 
                owner: tx_context::sender(ctx), 
                author: string::utf8(author), 
                contact: string::utf8(contact) 
            }
        );

        
        let idea = Idea {
            id: id,
            name: string::utf8(name),
            owner: tx_context::sender(ctx),
            author: string::utf8(author),
            img_url: url::new_unsafe_from_bytes(img_url),
            description: option::none(),
            years_of_invention,
            technologies: string::utf8(technologies),
            portfolio: string::utf8(portfolio),
            contact: string::utf8(contact),
            open_to_sale: true,
        };

        
        object_table::add(&mut ideas.cards, ideas.counter, idea);
    }

   
    public entry fun update_card_description(ideas: &mut Ideas, new_description: vector<u8>, id: u64, ctx: &mut TxContext) {
        let user_card = object_table::borrow_mut(&mut ideas.cards, id);
        assert!(tx_context::sender(ctx) == user_card.owner, NOT_THE_OWNER);
        let old_value = option::swap_or_fill(&mut user_card.description, string::utf8(new_description));

        event::emit(DescriptionUpdated {
            name: user_card.name,
            owner: user_card.owner,
            new_description: string::utf8(new_description)
        });

       
        _ = old_value;
    }

   
    public entry fun deactivate_card(ideas: &mut Ideas, id: u64, ctx: &mut TxContext) {
        let card = object_table::borrow_mut(&mut ideas.cards, id);
        assert!(card.owner == tx_context::sender(ctx), NOT_THE_OWNER);
        card.open_to_sale = false;
    }

    public fun get_card_info(ideas: &Ideas, id: u64): (
        String,
        address,
        String,
        Url,
        Option<String>,
        u8,
        String,
        String,
        String,
        bool,
    ) {
        let card = object_table::borrow(&ideas.cards, id);
        (
            card.name,
            card.owner,
            card.author,
            card.img_url,
            card.description,
            card.years_of_invention,
            card.technologies,
            card.portfolio,
            card.contact,
            card.open_to_sale
        )
    }
    mod tests {
        use super::*;
        use sui::coin::Coin;
    
        #[test]
        fn test_create_card() {
            let mut ctx = TxContext::new(); // Create a mock transaction context
            let mut ideas = Ideas {
                id: UID::default(),
                owner: Default::default(),
                counter: 0,
                cards: ObjectTable::new(&mut ctx),
            };
    
            let name = b"MyCardName".to_vec();
            let author = b"AuthorName".to_vec();
            let img_url = b"http://example.com/image.jpg".to_vec();
            let years_of_invention = 5;
            let technologies = b"Tech1, Tech2".to_vec();
            let portfolio = b"My Portfolio".to_vec();
            let contact = b"contact@example.com".to_vec();
            let payment = Coin::<SUI>::new(1);
    
            create_card(
                name.clone(),
                author.clone(),
                img_url.clone(),
                years_of_invention,
                technologies.clone(),
                portfolio.clone(),
                contact.clone(),
                payment,
                &mut ideas,
                &mut ctx,
            );
    
            assert_eq!(ideas.counter, 1);
    
            // Retrieve the card information and assert its correctness
            let card_info = get_card_info(&ideas, 1);
            assert_eq!(card_info.0, String::from_utf8(name).unwrap());
            assert_eq!(card_info.2, String::from_utf8(author).unwrap());
            assert_eq!(card_info.4.unwrap(), ""); // Description should be empty initially
            assert_eq!(card_info.5, years_of_invention);
            assert_eq!(card_info.6, String::from_utf8(technologies).unwrap());
            assert_eq!(card_info.7, String::from_utf8(portfolio).unwrap());
            assert_eq!(card_info.8, String::from_utf8(contact).unwrap());
            assert_eq!(card_info.9, true); // open_to_sale should be true initially
        }
    
        #[test]
        fn test_update_card_description() {
            let mut ctx = TxContext::new();
            let mut ideas = Ideas {
                id: UID::default(),
                owner: Default::default(),
                counter: 0,
                cards: ObjectTable::new(&mut ctx),
            };
    
            // Create a card
            let payment = Coin::<SUI>::new(1);
            create_card(
                b"MyCardName".to_vec(),
                b"AuthorName".to_vec(),
                b"http://example.com/image.jpg".to_vec(),
                5,
                b"Tech1, Tech2".to_vec(),
                b"My Portfolio".to_vec(),
                b"contact@example.com".to_vec(),
                payment,
                &mut ideas,
                &mut ctx,
            );
    
            // Get the ID of the created card
            let card_id = ideas.counter;
    
            // Update the description
            let new_description = b"Updated description".to_vec();
            update_card_description(&mut ideas, new_description.clone(), card_id, &mut ctx);
    
            // Retrieve the card information and assert the description is updated
            let updated_card_info = get_card_info(&ideas, card_id);
            assert_eq!(
                updated_card_info.4.unwrap(),
                String::from_utf8(new_description).unwrap()
            );
        }
    
        #[test]
        fn test_deactivate_card() {
            let mut ctx = TxContext::new();
            let mut ideas = Ideas {
                id: UID::default(),
                owner: Default::default(),
                counter: 0,
                cards: ObjectTable::new(&mut ctx),
            };
    
            // Create a card
            let payment = Coin::<SUI>::new(1);
            create_card(
                b"MyCardName".to_vec(),
                b"AuthorName".to_vec(),
                b"http://example.com/image.jpg".to_vec(),
                5,
                b"Tech1, Tech2".to_vec(),
                b"My Portfolio".to_vec(),
                b"contact@example.com".to_vec(),
                payment,
                &mut ideas,
                &mut ctx,
            );
    
            // Get the ID of the created card
            let card_id = ideas.counter;
    
            // Deactivate the card
            deactivate_card(&mut ideas, card_id, &mut ctx);
    
            // Retrieve the card information and assert open_to_sale is false
            let deactivated_card_info = get_card_info(&ideas, card_id);
            assert_eq!(deactivated_card_info.9, false);
        }
    }

}
